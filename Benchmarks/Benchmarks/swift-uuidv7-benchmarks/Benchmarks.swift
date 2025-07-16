import Benchmark
import Foundation
import UUIDV7

let benchmarks = { @Sendable in
  Benchmark(
    "UUIDV4 Generation Throughput",
    configuration: Benchmark.Configuration(
      metrics: [.throughput, .wallClock],
      scalingFactor: .mega
    )
  ) { @MainActor benchmark async in
    for _ in benchmark.scaledIterations {
      blackHole(UUID())
    }
  }

  Benchmark(
    "UUIDV7 Generation Throughput",
    configuration: Benchmark.Configuration(
      metrics: [.throughput, .wallClock],
      scalingFactor: .mega
    )
  ) { @MainActor benchmark async in
    for _ in benchmark.scaledIterations {
      blackHole(UUIDV7())
    }
  }
}
