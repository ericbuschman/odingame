package main

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

Particle :: struct {
	position:     rl.Vector2,
	velocity:     rl.Vector2,
	lifetime:     f32,
	max_lifetime: f32,
	color:        rl.Color,
	size:         f32,
	active:       bool,
}

Particle_System :: struct {
	particles: [dynamic]Particle,
}

particle_system_init :: proc() -> Particle_System {
	return Particle_System {
		particles = make([dynamic]Particle, 0, 200),
	}
}

particle_system_deinit :: proc(ps: ^Particle_System) {
	delete(ps.particles)
}

particle_emit_collision :: proc(ps: ^Particle_System, position: rl.Vector2, color: rl.Color) {
	PARTICLE_COUNT :: 10
	angle_step: f32 = 360.0 / f32(PARTICLE_COUNT)

	for i in 0 ..< PARTICLE_COUNT {
		angle := angle_step * f32(i) * rl.PI / 180.0
		speed := 100.0 + f32(rand.int31_max(100))

		velocity := rl.Vector2 {
			math.cos(angle) * speed,
			math.sin(angle) * speed,
		}

		lifetime := 0.3 + f32(rand.int31_max(30)) / 100.0
		size := 2.0 + f32(rand.int31_max(20)) / 10.0

		append(&ps.particles, Particle {
			position     = position,
			velocity     = velocity,
			lifetime     = lifetime,
			max_lifetime = lifetime,
			color        = color,
			size         = size,
			active       = true,
		})
	}
}

particle_emit_trail :: proc(ps: ^Particle_System, position: rl.Vector2, color: rl.Color) {
	velocity := rl.Vector2 {
		f32(rand.int31_max(40) - 20),
		f32(rand.int31_max(40) - 20),
	}

	append(&ps.particles, Particle {
		position     = position,
		velocity     = velocity,
		lifetime     = 0.2,
		max_lifetime = 0.2,
		color        = color,
		size         = 1.5,
		active       = true,
	})
}

particle_system_update :: proc(ps: ^Particle_System) {
	dt := rl.GetFrameTime()

	i := 0
	for i < len(ps.particles) {
		p := &ps.particles[i]
		if !p.active {
			unordered_remove(&ps.particles, i)
			continue
		}

		p.position += p.velocity * dt
		p.velocity.y += 300 * dt // gravity
		p.lifetime -= dt

		if p.lifetime <= 0 {
			unordered_remove(&ps.particles, i)
			continue
		}

		i += 1
	}
}

particle_system_draw :: proc(ps: ^Particle_System) {
	for &p in ps.particles {
		alpha := p.lifetime / p.max_lifetime
		fade_color := rl.Color {
			p.color.r,
			p.color.g,
			p.color.b,
			u8(255.0 * alpha),
		}
		rl.DrawCircleV(p.position, p.size, fade_color)
	}
}
