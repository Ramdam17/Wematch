import XCTest
@testable import Wematch

/// Guards the two measured properties the heart palette rests on.
///
/// A participant is identified by the colour of their heart as it moves across the plot,
/// so hues must be far enough apart to tell apart. And because the fills are pastels on a
/// near-white background in light mode, it is `plotMarkerOutline` — not the fill — that
/// satisfies the 3:1 requirement for a graphical object (WCAG SC 1.4.11). Both properties
/// are invisible in a diff: a well-meaning tweak to a hex or to the outline alpha can
/// break them silently. Hence these tests.
///
/// History worth keeping: the palette that preceded this one had five pairs under
/// CIEDE2000 dE 2.2, two of them at dE 0.6 — participants who were literally the same
/// colour — and nothing failed.
final class HeartPaletteSeparabilityTests: XCTestCase {

    /// dE 10 is roughly where two colours read as different rather than as two shades of
    /// one. The palette measures 11.8, so this leaves a little headroom for future tuning
    /// without leaving room for a collision.
    private let minimumPairwiseDistance = 10.0

    /// WCAG SC 1.4.11, graphical objects.
    private let minimumContrast = 3.0

    /// Below this, the outline stops reading as an edge and dissolves into the fill.
    private let minimumOutlineToFillContrast = 1.5

    // MARK: - Separability

    func testEveryPairOfHuesIsPerceptuallyDistinct() {
        let labs = WematchTheme.heartColorHexes.map { Lab(hex: $0) }
        var worst = (distance: Double.greatestFiniteMagnitude, a: 0, b: 0)

        for i in labs.indices {
            for j in labs.indices where j > i {
                let distance = labs[i].distance(to: labs[j])
                if distance < worst.distance {
                    worst = (distance, i, j)
                }
            }
        }

        XCTAssertGreaterThanOrEqual(
            worst.distance, minimumPairwiseDistance,
            """
            slots \(worst.a + 1) (\(WematchTheme.heartColorHexes[worst.a])) and \
            \(worst.b + 1) (\(WematchTheme.heartColorHexes[worst.b])) are only \
            dE \(String(format: "%.1f", worst.distance)) apart — two participants would \
            share a colour
            """
        )
    }

    // MARK: - Contrast

    func testFillsClearTheContrastFloorOnTheDarkBackgrounds() {
        // In Dark Cosmic the fills stand on their own, so no outline is drawn there.
        for hex in WematchTheme.heartColorHexes {
            for background in WematchTheme.backgroundHexesDark {
                XCTAssertGreaterThanOrEqual(
                    contrastRatio(hex, background), minimumContrast,
                    "\(hex) on \(background)"
                )
            }
        }
    }

    func testOutlineCarriesTheContrastFloorOnTheLightBackgrounds() {
        // The pastel fills cannot clear 3:1 on a near-white background — that is the whole
        // reason the outline exists. Assert the boundary does the job in their place.
        for background in WematchTheme.backgroundHexesLight {
            let outline = blackComposited(
                over: background,
                alpha: WematchTheme.plotMarkerOutlineLightAlpha
            )
            XCTAssertGreaterThanOrEqual(
                contrastRatio(outline, background), minimumContrast,
                "outline over \(background) reaches only \(contrastRatio(outline, background))"
            )
        }
    }

    func testOutlineStaysVisibleAgainstEveryFill() {
        let outline = blackComposited(
            over: WematchTheme.backgroundHexesLight[0],
            alpha: WematchTheme.plotMarkerOutlineLightAlpha
        )

        for hex in WematchTheme.heartColorHexes {
            XCTAssertGreaterThanOrEqual(
                contrastRatio(outline, hex), minimumOutlineToFillContrast,
                "the outline dissolves into \(hex); lower the alpha further and the shape " +
                "loses its boundary"
            )
        }
    }

    // MARK: - Colour Maths

    /// CIE L*a*b*, spelled out rather than as `l`, `a`, `b` so the names clear the
    /// project's minimum-identifier-length rule without widening its exclusion list.
    private struct Lab {
        let lStar: Double
        let aStar: Double
        let bStar: Double

        init(hex: String) {
            let (r, g, blue) = linearComponents(hex)
            let tristimulusX = r * 0.4124564 + g * 0.3575761 + blue * 0.1804375
            let tristimulusY = r * 0.2126729 + g * 0.7151522 + blue * 0.0721750
            let tristimulusZ = r * 0.0193339 + g * 0.1191920 + blue * 0.9503041

            func f(_ t: Double) -> Double {
                t > 216.0 / 24389.0 ? cbrt(t) : (841.0 / 108.0) * t + 4.0 / 29.0
            }

            // D65 white point
            let fx = f(tristimulusX / 0.95047)
            let fy = f(tristimulusY)
            let fz = f(tristimulusZ / 1.08883)
            self.lStar = 116 * fy - 16
            self.aStar = 500 * (fx - fy)
            self.bStar = 200 * (fy - fz)
        }

        /// CIEDE2000 (Sharma, Wu & Dalal 2005, DOI 10.1002/col.20070), the current CIE
        /// recommendation. CIE76 would overstate differences among saturated hues, which
        /// is most of this palette.
        func distance(to other: Lab) -> Double {
            let c1 = (aStar * aStar + bStar * bStar).squareRoot()
            let c2 = (other.aStar * other.aStar + other.bStar * other.bStar).squareRoot()
            let cBar = (c1 + c2) / 2
            let cBar7 = pow(cBar, 7)
            let g = 0.5 * (1 - (cBar7 / (cBar7 + pow(25, 7))).squareRoot())

            let a1p = (1 + g) * aStar
            let a2p = (1 + g) * other.aStar
            let c1p = (a1p * a1p + bStar * bStar).squareRoot()
            let c2p = (a2p * a2p + other.bStar * other.bStar).squareRoot()

            let h1p = degrees(atan2(bStar, a1p))
            let h2p = degrees(atan2(other.bStar, a2p))

            let dLp = other.lStar - lStar
            let dCp = c2p - c1p

            let dhp: Double
            if c1p * c2p == 0 {
                dhp = 0
            } else if abs(h2p - h1p) <= 180 {
                dhp = h2p - h1p
            } else if h2p - h1p > 180 {
                dhp = h2p - h1p - 360
            } else {
                dhp = h2p - h1p + 360
            }
            let dHp = 2 * (c1p * c2p).squareRoot() * sin(radians(dhp) / 2)

            let lpBar = (lStar + other.lStar) / 2
            let cpBar = (c1p + c2p) / 2

            let hpBar: Double
            if c1p * c2p == 0 {
                hpBar = h1p + h2p
            } else if abs(h1p - h2p) <= 180 {
                hpBar = (h1p + h2p) / 2
            } else if h1p + h2p < 360 {
                hpBar = (h1p + h2p + 360) / 2
            } else {
                hpBar = (h1p + h2p - 360) / 2
            }

            let t = 1
                - 0.17 * cos(radians(hpBar - 30))
                + 0.24 * cos(radians(2 * hpBar))
                + 0.32 * cos(radians(3 * hpBar + 6))
                - 0.20 * cos(radians(4 * hpBar - 63))

            let dTheta = 30 * exp(-pow((hpBar - 275) / 25, 2))
            let cpBar7 = pow(cpBar, 7)
            let rc = 2 * (cpBar7 / (cpBar7 + pow(25, 7))).squareRoot()
            let sl = 1 + (0.015 * pow(lpBar - 50, 2)) / (20 + pow(lpBar - 50, 2)).squareRoot()
            let sc = 1 + 0.045 * cpBar
            let sh = 1 + 0.015 * cpBar * t
            let rt = -sin(radians(2 * dTheta)) * rc

            return (pow(dLp / sl, 2) + pow(dCp / sc, 2) + pow(dHp / sh, 2)
                    + rt * (dCp / sc) * (dHp / sh)).squareRoot()
        }

        private func degrees(_ radians: Double) -> Double {
            let value = radians * 180 / .pi
            return value < 0 ? value + 360 : value
        }

        private func radians(_ degrees: Double) -> Double {
            degrees * .pi / 180
        }
    }

    private func contrastRatio(_ first: String, _ second: String) -> Double {
        let l1 = relativeLuminance(first)
        let l2 = relativeLuminance(second)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    private func relativeLuminance(_ hex: String) -> Double {
        let (r, g, b) = linearComponents(hex)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// Black at `alpha` over an opaque background, which is what `adaptiveInk` draws.
    private func blackComposited(over background: String, alpha: Double) -> String {
        let components = srgbComponents(background).map { $0 * (1 - alpha) }
        return components
            .map { String(format: "%02X", Int((max(0, min(1, $0)) * 255).rounded())) }
            .joined()
    }
}

// MARK: - Shared Helpers

private func srgbComponents(_ hex: String) -> [Double] {
    let value = UInt32(hex, radix: 16) ?? 0
    return [(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF].map { Double($0) / 255 }
}

private func linearComponents(_ hex: String) -> (Double, Double, Double) {
    let linear = srgbComponents(hex).map { channel in
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }
    return (linear[0], linear[1], linear[2])
}
