{ ... }:
{
  # Low battery notifications (warning at 20%, critical at 10%, shutdown at 3%)
  services.batsignal = {
    enable = true;
    extraArgs = [ "-w" "20" "-c" "10" "-d" "3" "-n" "Battery" ];
  };
}
