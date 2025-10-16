{
  description = "Aila Whisper + Piper Environment";

  outputs = { self, nixpkgs }: {
    devShells.x86_64-linux.default =
      nixpkgs.legacyPackages.x86_64-linux.mkShell {
        buildInputs = with nixpkgs.legacyPackages.x86_64-linux; [
          whispercpp
          ffmpeg
          python3
          python3Packages.numpy
          piper-tts
          sox
        ];

        shellHook = ''
          echo "🎧 Whisper + Piper 环境已就绪"
          echo "运行示例: bash scripts/record_and_transcribe.sh"
        '';
      };
  };
}