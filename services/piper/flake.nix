{
  description = "Piper TTS Service for Aila (Natural Female Voice)";
  outputs = { self, nixpkgs }: {
    devShells.x86_64-linux.default =
      nixpkgs.legacyPackages.x86_64-linux.mkShell {
        buildInputs = with nixpkgs.legacyPackages.x86_64-linux; [
          piper
          ffmpeg
          sox
        ];
        shellHook = ''
          echo "🎤 Piper TTS Environment ready"
          echo "Use: piper --model /aila/models/piper-zh-xiaoyue.onnx --output_file out.wav"
        '';
      };
  };
}