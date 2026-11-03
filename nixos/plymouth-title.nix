{ pkgs, ... }:

let
  title = "Medallian's Humming!";
  themeName = "spinner-title";

  # The stock spinner with a line of text above it. Only the .plymouth file is
  # new: ImageDir still points at spinner, the same way the bgrt theme borrows
  # its images, and the NixOS module pulls that theme into the initrd for it.
  theme = pkgs.runCommand "plymouth-${themeName}" { } ''
    dir=$out/share/plymouth/themes/${themeName}
    mkdir -p $dir
    sed \
      -e 's/^Name=.*/Name=Spinner with title/' \
      -e '/^Name\[/d' \
      -e 's/^TitleFont=.*/TitleFont=JetBrainsMono Nerd Font 22/' \
      -e 's/^TitleVerticalAlignment=.*/TitleVerticalAlignment=.62/' \
      -e '/^\[boot-up\]/a Title=${title}' \
      ${pkgs.plymouth}/share/plymouth/themes/spinner/spinner.plymouth > $dir/${themeName}.plymouth
  '';
in
{
  boot.plymouth = {
    theme = themeName;
    themePackages = [ theme ];
    # The initrd only carries this one font, so it decides how the title looks.
    font = "${pkgs.nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFont-Regular.ttf";
  };
}
