#include "../src/driver/sync.h"
#include <cstdlib>
#include <iostream>

static const V3 stations[] = {{-2, 2, -3}, {2, 2.3, 3}};
static void require(bool ok, const char *message) {
  if (!ok) { std::cerr << "FAIL: " << message << '\n'; std::exit(1); }
}
static void setup(Solver &s) {
  for (int k = 0; k < 2; ++k) {
    V3 z = stations[k] * (1 / norm(stations[k]));
    M3 r; r.m[0][2] = z.x; r.m[1][2] = z.y; r.m[2][2] = z.z;
    s.SetStation(k ? "B" : "A", stations[k], r);
  }
  s.Reset({0, 0, 0, 0});
}
static void observations(Solver &s, double start, int count, bool both, V3 shift = {}) {
  for (int i = 0; i < count; ++i) {
    V3 o = {((i / 2) % 25 - 12) * .08, ((i / 50) % 7) * .07,
            ((i / 350) % 13 - 6) * .09};
    int k = both ? i % 2 : 0;
    V3 d = stations[k] + shift - o;
    s.Add(start + i * .001, o, d * (1 / norm(d)), NAN, 0, true);
  }
}
static double distance(const X4 &a, const X4 &b) {
  double d = 0; for (int i = 0; i < 4; ++i) d += std::fabs(a[i] - b[i]); return d;
}
int main() {
  auto quiet = [](const std::string &) {};
  Solver one(quiet, 7, {}); setup(one);
  observations(one, 10, 3000, false, {.025, 0, 0});
  one.Step(13);
  require(distance(one.x(), {0, 0, 0, 0}) < 1e-12, "single station must not move alignment");

  Solver visible(quiet, 7, {}); setup(visible);
  observations(visible, 10, 6000, true, {.025, 0, 0});
  StepStat good = visible.Step(16);
  require(good.cond, "diverse two-station geometry must allow correction");
  require(visible.x()[1] > .015 && visible.x()[1] < .035, "valid correction must recover translation");
  X4 saved = visible.x();
  observations(visible, 30, 3000, false, {.06, 0, 0});
  StepStat hidden = visible.Step(33);
  require(!hidden.cond, "old second-station rays must not count as fresh evidence");
  require(distance(visible.x(), saved) < 1e-12, "occlusion must hold the last correction");
  observations(visible, 40, 6000, true, {.025, 0, 0});
  require(visible.Step(46).cond, "correction must resume after two stations return");

  Solver empty(quiet, 7, {}); setup(empty);
  X4 before = empty.x(); empty.Step(100);
  require(distance(before, empty.x()) == 0, "no sightings must hold alignment");
  std::cout << "PASS: single station, two-station correction, occlusion, recovery, no sightings\n";
}
