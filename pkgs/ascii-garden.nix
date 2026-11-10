# The lock screen's ASCII garden: JPEG frames (0.jpg .. N-1.jpg) baked once
# at build time by ./ascii-garden.py.
{ runCommand, python3, jetbrains-mono }:
runCommand "ascii-garden" { nativeBuildInputs = [ (python3.withPackages (p: [ p.numpy p.pillow ])) ]; } ''
  python3 -W ignore ${./ascii-garden.py} ${jetbrains-mono}/share/fonts/truetype/JetBrainsMono-Regular.ttf $out
''
