import SwiftUI

struct AnimatedBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: WematchTheme.backgroundColors,
                startPoint: animate ? .topLeading : .topTrailing,
                endPoint: animate ? .bottomTrailing : .bottomLeading
            )

            FloatingParticlesView()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

// MARK: - Floating Particles

private struct FloatingParticlesView: View {
    @State private var particles: [Particle] = []
    @State private var timer: Timer?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 15)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let age = now - particle.birth
                    guard age < particle.lifetime else { continue }
                    let progress = age / particle.lifetime

                    // Float upward and drift sideways
                    let x = particle.startX * size.width + sin(age * particle.drift) * 30
                    let y = particle.startY * size.height - CGFloat(age) * particle.speed

                    // Fade in then out
                    let alpha = progress < 0.2
                        ? progress / 0.2
                        : (1 - progress) / 0.8
                    let radius = particle.radius * (1 + CGFloat(progress) * 0.5)

                    context.opacity = alpha * particle.maxOpacity
                    context.fill(
                        Circle().path(in: CGRect(
                            x: x - radius, y: y - radius,
                            width: radius * 2, height: radius * 2
                        )),
                        with: .color(particle.color)
                    )
                }
            }
        }
        .onAppear { startSpawning() }
        .onDisappear { timer?.invalidate() }
    }

    private func startSpawning() {
        spawnParticle()
        timer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            Task { @MainActor in
                spawnParticle()
                // Remove dead particles
                let now = Date.timeIntervalSinceReferenceDate
                particles.removeAll { now - $0.birth > $0.lifetime }
            }
        }
    }

    private func spawnParticle() {
        particles.append(Particle(
            startX: Double.random(in: 0.05...0.95),
            startY: Double.random(in: 0.7...1.1),
            speed: CGFloat.random(in: 20...50),
            drift: Double.random(in: 0.5...1.5),
            radius: CGFloat.random(in: 4...10),
            maxOpacity: Double.random(in: 0.15...0.35),
            lifetime: Double.random(in: 6...12),
            color: WematchTheme.heartColors.randomElement() ?? .purple,
            birth: Date.timeIntervalSinceReferenceDate
        ))
    }
}

private struct Particle {
    let startX: Double
    let startY: Double
    let speed: CGFloat
    let drift: Double
    let radius: CGFloat
    let maxOpacity: Double
    let lifetime: Double
    let color: Color
    let birth: TimeInterval
}

#Preview {
    AnimatedBackground()
}
