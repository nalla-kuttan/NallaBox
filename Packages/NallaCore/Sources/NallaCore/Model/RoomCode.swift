/// Four-letter room codes without vowels, Y, I, O or L: easy to read aloud and can't spell words.
public enum RoomCode {
    public static let alphabet = "BCDFGHJKMNPQRSTVWXZ"

    public static func generate<R: RandomNumberGenerator>(using rng: inout R) -> String {
        let letters = Array(alphabet)
        return String((0..<4).map { _ in letters.randomElement(using: &rng)! })
    }
}
