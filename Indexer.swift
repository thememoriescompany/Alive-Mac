
import NaturalLanguage
import Foundation
import Combine

public enum IndexSpeed: String {
  case standard
  case fast
}

public final class Indexer<A: IndexItem & Comparable> {

  public init(
    speed: IndexSpeed,
    progressQueue: DispatchQueue = DispatchQueue(label: "com.alive.progressQueue"),
    accesQueue: DispatchQueue = DispatchQueue(label: "com.alive.index_access", attributes: DispatchQueue.Attributes.concurrent))
  {
    self.progressQueue = progressQueue
    self.index = Index<A>(accessQueue: accesQueue)
    operationQueue.qualityOfService = .background
    let processors = ProcessInfo.processInfo.processorCount
    let maxOperations = speed == .standard ? max(1, processors-2) : processors
    operationQueue.maxConcurrentOperationCount = maxOperations
    vendor = ThreadSafeVendor(maxItems: maxOperations) {
      NLTagger(tagSchemes: [.lemma])
    }
  }

  @Published public private(set) var isFinished: Bool = true
  @Published public private(set) var totalProgress: Double = 0
  
  let index: Index<A>

  public func indexItems(diff: CollectionDifference<A>, completion: @escaping (Double) -> Void) {
    let shouldReportProgress: Bool
    if startingItemsCount == nil {
      startingItemsCount = diff.insertions.count
      shouldReportProgress = true
      if diff.insertions.count > 0 {
        totalProgress = 0
        isFinished = false
      }
    } else {
      shouldReportProgress = false
    }

    let beginTime = DispatchTime.now()
    let completedOperation = BlockOperation { [weak self] in
      let endTime = DispatchTime.now()
      if shouldReportProgress {
        self?.progressQueue.sync {
          self?.isFinished = true
        }
      }
      completion(Double(endTime.uptimeNanoseconds - beginTime.uptimeNanoseconds)/1_000_000_000)
    }
    completedOperation.qualityOfService = .background
    for collectionDiff in diff.insertions + diff.removals {
      switch collectionDiff {
      case .insert(offset: _, element: let item, associatedWith: _):
        let op = insertOperation(for: item, shouldReportProgress: shouldReportProgress)
        completedOperation.addDependency(op)
        operationQueue.addOperation(op)
      case .remove(offset: _, element: let item, associatedWith: _):
        operationQueue.addBarrierBlock { [weak self] in
          self?.index.remove(item: item)
        }
        break
      }
    }
    operationQueue.addOperation(completedOperation)
  }

  public func resume() {
    operationQueue.isSuspended = false
  }

  public func pause() {
    operationQueue.isSuspended = true
  }

  public func query(string: String) -> [A] {
    index.query(string: string)
  }

  public func debug(item: A) -> ProcessedLanguage? {
    index.debug(item: item)
  }

  private let indexContext = IndexContext()
  private var startingItemsCount: Int? = nil
  private let operationQueue = OperationQueue()
  private let vendor: ThreadSafeVendor<NLTagger>
  private let progressQueue: DispatchQueue

  // Always accessed on progressQueue
  private var completed: Double = 0 {
    didSet {
      guard let startingItemsCount = startingItemsCount, startingItemsCount > 0 else { return }

      let result = completed/Double(startingItemsCount)
      totalProgress = result
    }
  }

  private func insertOperation(for item: A, shouldReportProgress: Bool) -> Operation {
    let op = BlockOperation { [indexContext = self.indexContext] in
      var lastProgress: Double = 0
      self.vendor.vend { [weak self] object in
        item.getSearchableRepresentation(
          indexContext: indexContext,
          progressHandler: { [weak self] theProgress in
          guard let self = self, shouldReportProgress else { return }

          self.progressQueue.sync {
            self.completed = self.completed + (theProgress - lastProgress)
          }
          lastProgress = theProgress
        }) { [weak self] searchable in
          guard let self = self else { return }
          self.index.add(
            dates: searchable.dates,
            item: item)
          self.index.add(
            keys: searchable.text,
            item: item,
            tagger: object)
          self.progressQueue.sync {
            self.completed = self.completed + (1.0 - lastProgress)
          }
        }
      }
    }
    op.qualityOfService = .background
    return op
  }

}

final class Index<A: Hashable & Comparable> {

  init(accessQueue: DispatchQueue) {
    self.accessQueue = accessQueue
  }

  private struct QueryResult<A: Hashable>: Hashable {
    let value: A
    let weight: Double
  }

  func add(keys: [[Text]], item: A, tagger: NLTagger) {
    var lemmaFrequency = [String: Int]()
    var originalWordFrequency = [String: Int]()
    var wordKeys = Set<String>()
    for key in keys {
      for text in key {
        tagger.string = text.string
        tagger.enumerateTags(in: tagger.string!.startIndex..<tagger.string!.endIndex, unit: .word, scheme: .lemma, options: .init()) { tag, range -> Bool in
          guard let originalString = tagger.string?[range].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return true }

          let computedValue = (tag?.rawValue ?? String(originalString)).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
          if !computedValue.isEmpty {
            if let freq = lemmaFrequency[computedValue] {
              lemmaFrequency[computedValue] = freq + 1
            } else {
              lemmaFrequency[computedValue] = 1
            }
            wordKeys.insert(computedValue)
            if originalString != computedValue {
              if let freq = originalWordFrequency[originalString] {
                originalWordFrequency[originalString] = freq + 1
              } else {
                originalWordFrequency[originalString] = 1
              }
              wordKeys.insert(originalString)
            }
          }
          return true
        }
      }
    }
    accessQueue.async(flags: .barrier) {
      self.discoveredWords[item] = ProcessedLanguage(recognizedText: keys, lemmas: lemmaFrequency, originalWords: originalWordFrequency)
      for key in wordKeys {
        if self.mapping[key] != nil {
          self.mapping[key]?.append(item)
        } else {
          self.mapping[key] = [item]
        }
      }
    }
  }

  func add(dates: Set<Date>, item: A) {
    accessQueue.async(flags: .barrier) {
      for date in dates {
        if self.dateMapping[date] != nil {
          self.dateMapping[date]?.append(item)
        } else {
          self.dateMapping[date] = [item]
        }
      }
    }
  }

  func remove(item: A) {
    accessQueue.async(flags: .barrier) {
      self.discoveredWords[item] = nil
      for key in self.dateMapping.keys {
        self.dateMapping[key] = self.dateMapping[key]?.filter { $0 != item }
      }
      for key in self.mapping.keys {
        self.mapping[key] = self.mapping[key]?.filter { $0 != item }
      }
    }
  }

  func debug(item: A) -> ProcessedLanguage? {
    var result: ProcessedLanguage? = nil
    accessQueue.sync {
      result = discoveredWords[item]
    }
    return result
  }

  private let accessQueue: DispatchQueue
  private var discoveredWords = [A: ProcessedLanguage]()
  private var mapping = [String: [A]]()
  private var dateMapping = [Date: [A]]()
  private let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

  // Safe to call from any thread
  fileprivate func query(string: String) -> [A] {
    // Get dates for this candidate
    let matches = detector?.matches(in: string, options: [], range: NSMakeRange(0, string.utf16.count))
    let dates = matches?.compactMap { $0.date } ?? []

    var resultsToWeight = [A: Double]()
    var queryMatches = [(Set<A>, Set<A>)]()
    let tagger = NLTagger(tagSchemes: [.lemma])
    let queries = string.lemmas(tagger: tagger)
    accessQueue.sync {
      for date in dates {
        for result in dateMapping[date] ?? [] {
          let currentWeight = resultsToWeight[result] ?? 0
          resultsToWeight[result] = currentWeight + 1.1
        }
      }

      queryMatches = queries.map { $0.lowercased() }.map { query -> (Set<A>, Set<A>) in
        let exactMatch = Set(mapping[query] ?? [])
        var partialMatch = Set<A>()
        if query.count > 3 {
          for (key, value) in mapping {
            if key.contains(query) {
              partialMatch = partialMatch.union(value)
            }
          }
        }
        return (exactMatch, partialMatch)
      }
    }

    let queryResults: [Set<QueryResult<A>>] = queryMatches.map { queryMatch in
      let exactMatch = queryMatch.0
      let partialMatch = queryMatch.1
      let both = exactMatch.intersection(partialMatch)
      let onlyExact = exactMatch.subtracting(both).map { QueryResult(value: $0, weight: 1) }
      let onlyPartial = partialMatch.subtracting(both).map { QueryResult(value: $0, weight: 0.1) }
      return Set(both.map { QueryResult(value: $0, weight: 1.1) }).union(onlyExact).union(onlyPartial)
    }

    for imageQueryResult in queryResults {
      for queryResult in imageQueryResult {
        let currentWeight = resultsToWeight[queryResult.value] ?? 0
        resultsToWeight[queryResult.value] = currentWeight + queryResult.weight
      }
    }
    return resultsToWeight.keys.sorted { first, second -> Bool in
      let firstWeight = resultsToWeight[first] ?? 0
      let secondWeight = resultsToWeight[second] ?? 0
      if firstWeight == secondWeight {
        return first > second
      }
      return firstWeight > secondWeight
    }
  }
}

