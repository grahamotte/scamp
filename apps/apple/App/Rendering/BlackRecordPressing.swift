import Foundation

struct BlackRecordPressing: Equatable {
    struct Band: Equatable {
        let innerRadius: CGFloat
        let outerRadius: CGFloat
        let grooves: [Groove]

        var midRadius: CGFloat { (innerRadius + outerRadius) / 2 }
        var width: CGFloat { outerRadius - innerRadius }
    }

    struct Groove: Equatable {
        let radius: CGFloat
        let width: CGFloat
        let strength: Double
    }

    struct Gap: Equatable {
        let radius: CGFloat
        let width: CGFloat
    }

    let bands: [Band]
    let gaps: [Gap]

    init(innerRadius: CGFloat, outerRadius: CGFloat, divisionRadii: [CGFloat]) {
        guard innerRadius.isFinite, outerRadius.isFinite,
              innerRadius >= 0, outerRadius > innerRadius else {
            bands = []
            gaps = []
            return
        }

        let divisions = Set(divisionRadii.filter {
            $0.isFinite && $0 > innerRadius && $0 < outerRadius
        }).sorted(by: >)
        let edges = [outerRadius] + divisions + [innerRadius]
        let gaps = divisions.enumerated().map { index, radius in
            Gap(
                radius: radius,
                width: min(
                    outerRadius * 0.009,
                    (edges[index] - radius) * 0.2,
                    (radius - edges[index + 2]) * 0.2
                )
            )
        }

        self.gaps = gaps
        bands = (0..<(edges.count - 1)).map { index in
            let outer = edges[index]
            let inner = edges[index + 1]
            let seed = Double(index + 1) * 7.31 + Double((outer - inner) / outerRadius) * 83.17
            let spacing = outerRadius * 0.028
            let margin = outerRadius * 0.003
            let cutOuter = outer - (index > 0 ? gaps[index - 1].width * 0.7 : margin)
            let cutInner = inner + (index < gaps.count ? gaps[index].width * 0.7 : margin)
            let cutWidth = max(0, cutOuter - cutInner)
            let count = min(3, Int((cutWidth / spacing).rounded(.down)))
            let grooves = (0..<count).map { grooveIndex in
                let unit = (CGFloat(grooveIndex) + 0.5) / CGFloat(count)
                let modulation = 0.5 + 0.5 * sin(Double(grooveIndex) * 1.71 + seed)
                return Groove(
                    radius: cutOuter - cutWidth * unit,
                    width: outerRadius * (0.0012 + CGFloat(modulation) * 0.0004),
                    strength: 0.7 + modulation * 0.3
                )
            }

            return Band(innerRadius: inner, outerRadius: outer, grooves: grooves)
        }
    }
}
