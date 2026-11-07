/// Collects discoveries without moving existing rows under the user's finger.
/// Call publish on the UI's refresh schedule; new arrivals are appended as a batch.
public struct StableDiscoveryList<Element: Identifiable> {
    public static var refreshInterval: Double { 3 }
    private var latest: [Element.ID: Element] = [:]
    private var order: [Element.ID] = []
    public init() {}
    public mutating func receive(_ element: Element) { latest[element.id] = element }
    public mutating func publish(newFirst: (Element, Element) -> Bool) -> [Element] {
        let known = Set(order)
        let arrivals = latest.values.filter { !known.contains($0.id) }.sorted(by: newFirst)
        order.append(contentsOf: arrivals.map(\.id))
        return order.compactMap { latest[$0] }
    }
}
