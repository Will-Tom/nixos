# Profiling / benchmarking (chess engine dev)
{ ... }:
{
  boot.kernel.sysctl."kernel.perf_event_paranoid" = 1;
  boot.kernelParams = [ "transparent_hugepage=madvise" ];
  # Steady clocks for SPRTs and benchmarks. The CPU uses amd-pstate-epp in active mode, so the
  # "performance" governor also sets the energy/performance preference (EPP) to performance.
  # Under full load the clock is temperature-limited anyway; this mainly removes ramp-up delay
  # and the idle downclocking between moves.
  powerManagement.cpuFreqGovernor = "performance";
}
