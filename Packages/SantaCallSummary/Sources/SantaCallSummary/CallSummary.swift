import Foundation

/// What a parent gets back from a call: what the child asked for, what they
/// promised, and anything else worth remembering.
///
/// Deliberately three lists rather than a paragraph. A wish list gathered in
/// October has to still be scannable in December, and prose is not scannable.
public struct CallSummary: Codable, Sendable, Equatable {

    public var wishes: [String]
    public var promises: [String]
    public var notable: [String]
    /// When the model produced this, not when the call happened. A summary is a
    /// derived thing and it is worth being able to tell how old the derivation is.
    public var generatedAt: Date

    public init(
        wishes: [String] = [],
        promises: [String] = [],
        notable: [String] = [],
        generatedAt: Date
    ) {
        self.wishes = wishes
        self.promises = promises
        self.notable = notable
        self.generatedAt = generatedAt
    }

    /// A call where the child mostly giggled. Worth distinguishing from "not
    /// summarised yet" — one is an answer, the other is an absence.
    public var isEmpty: Bool {
        wishes.isEmpty && promises.isEmpty && notable.isEmpty
    }
}
