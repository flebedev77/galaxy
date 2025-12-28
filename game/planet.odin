package game
import rl "vendor:raylib"
import planet_renderer "../planet_generator/planet"

Planet :: struct {
  is_static: bool,
  position: rl.Vector3,
  velocity: rl.Vector3,
  radius: f32,
  color: rl.Color,
  mass: f32,
  name: cstring,
  path_prediction_enabled: bool,
  model: planet_renderer.PlanetModel,
  has_model: bool,
  land_pos: rl.Vector3,
  radius_at_landing_site: f32,
  last_land_update: f32
}

planet_init :: proc(planet: ^Planet, planet_settings_path: string) {
  planet.has_model = true
  planet.model.settings = planet_renderer.settings_from_ini(planet_settings_path)
  planet_renderer.regenerate_planet(&planet.model)
  scl : f32 = planet.radius
  planet.model.model.transform = rl.MatrixScale(scl, scl, scl)
  planet.radius_at_landing_site = planet.radius
}

planet_draw :: proc(planet: ^Planet) {
  if !planet.has_model {
  } else {
    planet_renderer.render_planet(&planet.model, planet.position)
  }
  rl.DrawSphereWires(planet.position, planet.radius, 5, 5, planet.color)
}

planet_update :: proc(planet: ^Planet, dt: f32) {
  if planet.is_static {
    return 
  }
  d: rl.Vector3 = planet.position - (local_player.position + local_player.velocity * dt)
  l: f32 = rl.Vector3Length(d)

  if l == 0 {
    return
  }
  n: rl.Vector3 = d / l


  f: f32 = GRAVITATIONAL_CONSTANT * ((10000000 * planet.mass) / l)
  local_player.velocity += n * f * dt

  if l == 0 || l < planet.radius {
    local_player.velocity = 0
  }

  if l < 1000 { // TODO tune this physics range
    planet.last_land_update -= dt
    if planet.last_land_update < 0 || 1==1 {
      planet.last_land_update = 0.3
      relative_pos: rl.Vector3 = -d
      mesh := planet.model.model.meshes[0]

      closest_dot: f32 = -10
      closest_index: i32 = -1
      for i in 0..<mesh.vertexCount {
        height := mesh.texcoords2[i*2]
        x := mesh.vertices[i*3]
        y := mesh.vertices[i*3+1]
        z := mesh.vertices[i*3+2]
        len := rl.Vector3Length({x, y, z})

        dot := rl.Vector3DotProduct({x, y, z}/len, -n)
        if dot > closest_dot {
          closest_dot = dot
          planet.land_pos = planet.position + {x, y, z} * planet.radius
          planet.radius_at_landing_site = len * planet.radius
        }
      }
    }
  }
  rl.DrawSphere(planet.land_pos, 0.1, rl.RED)
  rl.DrawSphereWires(planet.position, planet.radius_at_landing_site, 10, 10, rl.ORANGE)

  if l < planet.radius_at_landing_site {
    local_player.throttle = 0
    local_player.velocity = 0
  }

  for &bullet in local_player.bullets {
    d = planet.position - bullet.position
    l = rl.Vector3Length(d)

    if l == 0 || l < planet.radius {
      // remove bullet
    }

    n = d / l
    f: f32 = GRAVITATIONAL_CONSTANT * ((10000 * planet.mass) / l)
    bullet.velocity += f * n * dt
  }
}

planet_unload :: proc(planet: Planet) {
  planet_renderer.unload_planet(planet.model)
}
