import SwiftUI

struct AnimatedBackground: View {
    @State private var animateGradient = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "FDF2F8"),
                    Color(hex: "F3E8FF"),
                    Color(hex: "EDE9FE")
                ],
                startPoint: animateGradient ? .topLeading : .bottomLeading,
                endPoint: animateGradient ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                    animateGradient.toggle()
                }
            }

            SparkleParticlesView()
        }
    }
}

private struct Particle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var size: Double
    var opacity: Double
    var speed: Double
}

private struct SparkleParticlesView: View {
    @State private var particles: [Particle] = (0..<8).map { _ in
        Particle(
            x: Double.random(in: 0...1),
            y: Double.random(in: 0...1),
            size: Double.random(in: 2...6),
            opacity: Double.random(in: 0.2...0.6),
            speed: Double.random(in: 0.3...1.0)
        )
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 10)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let drift = sin(time * particle.speed + particle.x * 10) * 0.02
                    let px = (particle.x + drift).truncatingRemainder(dividingBy: 1.0)
                    let py = (particle.y + time * particle.speed * 0.01)
                        .truncatingRemainder(dividingBy: 1.0)
                    let pulsingOpacity = particle.opacity * (0.5 + 0.5 * sin(time * particle.speed * 2))

                    let point = CGPoint(x: abs(px) * size.width, y: abs(py) * size.height)
                    let rect = CGRect(
                        x: point.x - particle.size / 2,
                        y: point.y - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )
                    context.opacity = pulsingOpacity
                    context.fill(Circle().path(in: rect), with: .color(.white))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

#Preview {
    AnimatedBackground()
}
