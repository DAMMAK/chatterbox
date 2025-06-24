# Use NVIDIA CUDA base image for GPU support
FROM nvidia/cuda:12.1-devel-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV TORCH_CUDA_ARCH_LIST="6.0 6.1 7.0 7.5 8.0 8.6+PTX"
ENV CUDA_HOME=/usr/local/cuda

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    git \
    wget \
    curl \
    build-essential \
    libsndfile1-dev \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd -m -u 1000 chatterbox && \
    mkdir -p /app && \
    chown chatterbox:chatterbox /app

# Set working directory
WORKDIR /app

# Switch to non-root user
USER chatterbox

# Upgrade pip and install wheel
RUN pip3 install --user --upgrade pip setuptools wheel

# Install PyTorch with CUDA support first (important for Chatterbox)
RUN pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Install Chatterbox TTS
RUN pip3 install --user chatterbox-tts

# Install additional dependencies that might be needed
RUN pip3 install --user \
    torchaudio \
    soundfile \
    librosa \
    numpy \
    scipy

# Create directories for input/output
RUN mkdir -p /app/input /app/output /app/models

# Copy example script (you can customize this)
COPY --chown=chatterbox:chatterbox <<EOF /app/run_tts.py
#!/usr/bin/env python3
import os
import sys
import torchaudio as ta
from chatterbox.tts import ChatterboxTTS

def main():
    # Initialize the model
    print("Loading Chatterbox TTS model...")
    
    # Check if CUDA is available
    device = "cuda" if os.system("nvidia-smi") == 0 else "cpu"
    print(f"Using device: {device}")
    
    try:
        model = ChatterboxTTS.from_pretrained(device=device)
        print("Model loaded successfully!")
    except Exception as e:
        print(f"Error loading model: {e}")
        sys.exit(1)
    
    # Default text if none provided
    text = os.getenv('TTS_TEXT', 
        "Hello! This is Chatterbox TTS running in Docker. "
        "The quick brown fox jumps over the lazy dog.")
    
    print(f"Generating speech for: {text}")
    
    # Generate audio
    try:
        audio_prompt_path = os.getenv('AUDIO_PROMPT_PATH')
        
        if audio_prompt_path and os.path.exists(audio_prompt_path):
            print(f"Using audio prompt: {audio_prompt_path}")
            wav = model.generate(text, audio_prompt_path=audio_prompt_path)
        else:
            print("Using default voice")
            wav = model.generate(text)
        
        # Save output
        output_path = os.getenv('OUTPUT_PATH', '/app/output/generated_speech.wav')
        ta.save(output_path, wav, model.sr)
        print(f"Audio saved to: {output_path}")
        
    except Exception as e:
        print(f"Error generating speech: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

# Make the script executable
RUN chmod +x /app/run_tts.py

# Set the PATH to include user installed packages
ENV PATH="/home/chatterbox/.local/bin:${PATH}"

# Expose any ports if needed (for web interfaces)
EXPOSE 8000

# Default command
CMD ["python3", "/app/run_tts.py"]
