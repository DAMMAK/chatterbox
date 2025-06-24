#!/bin/bash

# Chatterbox TTS Docker Setup Script
# This script helps you set up and run Chatterbox TTS in Docker

set -e

echo "🎙️  Chatterbox TTS Docker Setup"
echo "================================"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p input output models

# Check for NVIDIA Docker support
if command -v nvidia-docker &> /dev/null || docker info | grep -q nvidia; then
    echo "🚀 NVIDIA Docker support detected - GPU acceleration will be available"
    USE_GPU=true
else
    echo "⚠️  No NVIDIA Docker support detected - will use CPU-only mode"
    USE_GPU=false
fi

# Build the Docker image
echo "🔨 Building Docker image..."
docker build -t chatterbox-tts .

echo "✅ Build complete!"

# Function to run TTS generation
run_tts() {
    local text="$1"
    local audio_prompt="$2"
    
    if [ "$USE_GPU" = true ]; then
        echo "🎯 Running with GPU support..."
        if [ -n "$audio_prompt" ] && [ -f "input/$audio_prompt" ]; then
            docker run --rm --gpus all \
                -v "$(pwd)/input:/app/input:ro" \
                -v "$(pwd)/output:/app/output:rw" \
                -v "$(pwd)/models:/home/chatterbox/.cache:rw" \
                -e "TTS_TEXT=$text" \
                -e "AUDIO_PROMPT_PATH=/app/input/$audio_prompt" \
                chatterbox-tts
        else
            docker run --rm --gpus all \
                -v "$(pwd)/input:/app/input:ro" \
                -v "$(pwd)/output:/app/output:rw" \
                -v "$(pwd)/models:/home/chatterbox/.cache:rw" \
                -e "TTS_TEXT=$text" \
                chatterbox-tts
        fi
    else
        echo "🖥️  Running with CPU only..."
        if [ -n "$audio_prompt" ] && [ -f "input/$audio_prompt" ]; then
            docker run --rm \
                -v "$(pwd)/input:/app/input:ro" \
                -v "$(pwd)/output:/app/output:rw" \
                -v "$(pwd)/models:/home/chatterbox/.cache:rw" \
                -e "TTS_TEXT=$text" \
                -e "AUDIO_PROMPT_PATH=/app/input/$audio_prompt" \
                -e "CUDA_VISIBLE_DEVICES=" \
                chatterbox-tts
        else
            docker run --rm \
                -v "$(pwd)/input:/app/input:ro" \
                -v "$(pwd)/output:/app/output:rw" \
                -v "$(pwd)/models:/home/chatterbox/.cache:rw" \
                -e "TTS_TEXT=$text" \
                -e "CUDA_VISIBLE_DEVICES=" \
                chatterbox-tts
        fi
    fi
}

# Interactive mode
if [ $# -eq 0 ]; then
    echo ""
    echo "🎤 Interactive Mode"
    echo "=================="
    
    # Get text input
    echo "Enter the text you want to convert to speech:"
    read -r text_input
    
    # Check for reference audio
    echo ""
    echo "Do you want to use a reference audio file for voice cloning? (y/n)"
    read -r use_reference
    
    if [[ $use_reference =~ ^[Yy]$ ]]; then
        echo "Available audio files in ./input/:"
        ls -la input/ 2>/dev/null || echo "No files found in ./input/"
        echo ""
        echo "Enter the filename of the reference audio (should be in ./input/):"
        read -r audio_file
        
        if [ -f "input/$audio_file" ]; then
            echo "✅ Using reference audio: $audio_file"
            run_tts "$text_input" "$audio_file"
        else
            echo "❌ File not found: input/$audio_file"
            echo "Proceeding with default voice..."
            run_tts "$text_input"
        fi
    else
        run_tts "$text_input"
    fi
    
else
    # Command line mode
    case "$1" in
        "build")
            echo "🔨 Building Docker image..."
            docker build -t chatterbox-tts .
            ;;
        "run")
            if [ -z "$2" ]; then
                echo "Usage: $0 run \"Your text here\" [reference_audio.wav]"
                exit 1
            fi
            run_tts "$2" "$3"
            ;;
        "shell")
            echo "🐚 Starting interactive shell..."
            if [ "$USE_GPU" = true ]; then
                docker run --rm -it --gpus all \
                    -v "$(pwd)/input:/app/input:ro" \
                    -v "$(pwd)/output:/app/output:rw" \
                    -v "$(pwd)/models:/home/chatterbox/.cache:rw" \
                    chatterbox-tts /bin/bash
            else
                docker run --rm -it \
                    -v "$(pwd)/input:/app/input:ro" \
                    -v "$(pwd)/output:/app/output:rw" \
                    -v "$(pwd)/models:/home/chatterbox/.cache:rw" \
                    -e "CUDA_VISIBLE_DEVICES=" \
                    chatterbox-tts /bin/bash
            fi
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  build                           Build the Docker image"
            echo "  run \"text\" [reference.wav]     Generate TTS with optional voice cloning"
            echo "  shell                          Start interactive shell"
            echo "  help                           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                             # Interactive mode"
            echo "  $0 run \"Hello world\"           # Generate speech with default voice"
            echo "  $0 run \"Hello\" voice.wav       # Generate speech with voice cloning"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
fi

echo ""
echo "✨ Done! Check the ./output/ directory for generated audio files."
