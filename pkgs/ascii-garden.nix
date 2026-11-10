# The lock screen's ASCII garden: frames baked once at build time by
# ./ascii-garden.py (0.txt .. N-1.txt, Pango markup).
{ runCommand, python3 }:
runCommand "ascii-garden" { nativeBuildInputs = [ (python3.withPackages (p: [ p.numpy ])) ]; } ''
  python3 ${./ascii-garden.py} $out
''
