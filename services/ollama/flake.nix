{
  description = "Ollama GPU Runtime for Aila Service";

  outputs = { self, nixpkgs }: {
    devShells.x86_64-linux.default =
      nixpkgs.legacyPackages.x86_64-linux.mkShell {
        buildInputs = with nixpkgs.legacyPackages.x86_64-linux; [
          ollama
          cudaPackages.cudatoolkit
        ];
        shellHook = ''
          echo "🧠 Aila Ollama Service Environment ready"
          nvidia-smi | head -n 10
          echo "You can now run: ollama serve"
        '';
      };
  };
}