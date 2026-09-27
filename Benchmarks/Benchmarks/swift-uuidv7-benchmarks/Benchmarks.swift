import Benchmark
import Foundation
import UUIDV7

let benchmarks = { @Sendable in
  // MARK: - Generation

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

  // MARK: - String Encoding

  let uuidV4 = UUID(uuidString: "D486CF16-E095-4AD0-A871-492623CD654C")!
  let uuidV7 = UUIDV7(uuidString: "0198143F-F09C-772D-A29A-42B1CA62E784")!

  Benchmark(
    "UUIDV4 String Encoding Throughput",
    configuration: Benchmark.Configuration(
      metrics: [.throughput, .wallClock],
      scalingFactor: .mega
    )
  ) { @MainActor benchmark async in
    for _ in benchmark.scaledIterations {
      blackHole(identity(uuidV4).uuidString)
    }
  }

  Benchmark(
    "UUIDV7 String Encoding Throughput",
    configuration: Benchmark.Configuration(
      metrics: [.throughput, .wallClock],
      scalingFactor: .mega
    )
  ) { @MainActor benchmark async in
    for _ in benchmark.scaledIterations {
      blackHole(identity(uuidV7).uuidString)
    }
  }

  // MARK: - String Decoding

  let uuidV4String = uuidV4.uuidString
  let uuidV7String = uuidV7.uuidString

  Benchmark(
    "UUIDV4 String Decoding Throughput",
    configuration: Benchmark.Configuration(
      metrics: [.throughput, .wallClock],
      scalingFactor: .mega
    )
  ) { @MainActor benchmark async in
    for _ in benchmark.scaledIterations {
      blackHole(UUID(uuidString: identity(uuidV4String)))
    }
  }

  Benchmark(
    "UUIDV7 String Decoding Throughput",
    configuration: Benchmark.Configuration(
      metrics: [.throughput, .wallClock],
      scalingFactor: .mega
    )
  ) { @MainActor benchmark async in
    for _ in benchmark.scaledIterations {
      blackHole(UUIDV7(uuidString: identity(uuidV7String)))
    }
  }

  // MARK: - JSON Coding

  let uuidV4s = (0..<1_000).map { _ in UUID() }
  let uuidV7s = (0..<1_000).map { _ in UUIDV7() }
  let uuidV4sJSON = try! JSONEncoder().encode(uuidV4s)
  let uuidV7sJSON = try! JSONEncoder().encode(uuidV7s)

  Benchmark(
    "UUIDV4 JSON Encoding Throughput (1,000 UUIDs)",
    configuration: Benchmark.Configuration(
      metrics: [.throughput, .wallClock],
      scalingFactor: .one
    )
  ) { @MainActor benchmark async throws in
    let encoder = JSONEncoder()
    for _ in benchmark.scaledIterations {
      blackHole(try encoder.encode(uuidV4s))
    }
  }

  Benchmark(
    "UUIDV7 JSON Encoding Throughput (1,000 UUIDs)",
    configuration: Benchmark.Configuration(
      metrics: [.throughput, .wallClock],
      scalingFactor: .one
    )
  ) { @MainActor benchmark async throws in
    let encoder = JSONEncoder()
    for _ in benchmark.scaledIterations {
      blackHole(try encoder.encode(uuidV7s))
    }
  }

  Benchmark(
    "UUIDV4 JSON Decoding Throughput (1,000 UUIDs)",
    configuration: Benchmark.Configuration(
      metrics: [.throughput, .wallClock],
      scalingFactor: .one
    )
  ) { @MainActor benchmark async throws in
    let decoder = JSONDecoder()
    for _ in benchmark.scaledIterations {
      blackHole(try decoder.decode([UUID].self, from: uuidV4sJSON))
    }
  }

  Benchmark(
    "UUIDV7 JSON Decoding Throughput (1,000 UUIDs)",
    configuration: Benchmark.Configuration(
      metrics: [.throughput, .wallClock],
      scalingFactor: .one
    )
  ) { @MainActor benchmark async throws in
    let decoder = JSONDecoder()
    for _ in benchmark.scaledIterations {
      blackHole(try decoder.decode([UUIDV7].self, from: uuidV7sJSON))
    }
  }
}
