package main
import "core:fmt";
import "core:math";
import "core:strings";
import rl "vendor:raylib";
import rlgl "vendor:raylib/rlgl";

DEV :: false;
DEBUG :: true;

TARGET_FPS :: 60;

when DEV {
  WINDOW_WIDTH :: 1387
  WINDOW_HEIGHT :: 738
} else {
  WINDOW_WIDTH :: 1920
  WINDOW_HEIGHT :: 1080
}

GRAVITATIONAL_CONSTANT :: 0.0001;

FUTURE_STEPS :: 1000;
FUTURE_STEPS_DT :: 0.1;

Planet :: struct {
  is_static: bool,
  position: rl.Vector3,
  velocity: rl.Vector3,
  radius: f32,
  color: rl.Color,
  mass: f32,
  name: cstring,
  path_prediction_enabled: bool,
}

camera_focus_body: ^Planet;
camera_speed: f32 = 500;
camera_zoom_factor: f32 = 7;

mouse_enabled: bool = false;
mouse_ingui: bool = false;
mouse_pos: rl.Vector2 = {0, 0};

gui_rect: rl.Rectangle = {20, 20, 400, 800};

simulation_running: bool = false;
simulation_speed_scalar: f32 = 1;

init_camera :: proc(camera: ^rl.Camera) {
  camera.position = camera_focus_body.position + {0, 600, 0};
  camera.target = camera_focus_body.position;
  camera.up = {0, 1, 0.001};
  camera.fovy = 65;
  camera.projection = .PERSPECTIVE;
}

update_camera :: proc(camera: ^rl.Camera, dt_warped: f32) {
    rl.UpdateCamera(camera, .THIRD_PERSON);
    dt := dt_warped * (1 / simulation_speed_scalar);
    scroll: f32 = -rl.GetMouseWheelMove() * dt * 60;
    camera_dir: rl.Vector3 = camera.position - camera_focus_body.position;
    camera_len: f32 = rl.Vector3Length(camera_dir);
    normalized_camera_dir: rl.Vector3 = camera_dir / camera_len;
    zoom_factor: f32 = 1 + (camera_len / camera_zoom_factor);
    camera.position = normalized_camera_dir * (camera_len + scroll * zoom_factor) + camera_focus_body.position;

    if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) {
      camera_focus_body.position.x -= camera_speed * dt; 
      camera.position.x -= camera_speed * dt;
    }
    if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) {
      camera_focus_body.position.z += camera_speed * dt; 
      camera.position.z += camera_speed * dt;
    }
    if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) {
      camera_focus_body.position.x += camera_speed * dt; 
      camera.position.x += camera_speed * dt;
    }
    if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) {
      camera_focus_body.position.z -= camera_speed * dt; 
      camera.position.z -= camera_speed * dt;
    }
    if rl.IsKeyDown(.LEFT_SHIFT) {
      camera_focus_body.position.y += camera_speed * dt; 
      camera.position.y += camera_speed * dt;
    }
    if rl.IsKeyDown(.LEFT_CONTROL) {
      camera_focus_body.position.y -= camera_speed * dt; 
      camera.position.y -= camera_speed * dt;
    }
    if !camera_focus_body.is_static && simulation_running {
      camera.position += camera_focus_body.velocity * dt_warped;
    }
    camera.target = camera_focus_body.position;
}


main :: proc() {
  rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Game");
  rl.SetTargetFPS(TARGET_FPS);
  rl.DisableCursor();
  rlgl.SetClipPlanes(0.01, 100000);

  when !DEV {
    rl.ToggleFullscreen();
  }


  stars_texture := rl.LoadTexture("res/stars.jpg");
  skybox := rl.LoadModelFromMesh(rl.GenMeshCube(10000, 10000, 10000));
  skybox.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = stars_texture;

  rl.GuiLoadStyle("res/dark.rgs");

  sekuya_font: rl.Font = rl.LoadFont("res/Sekuya-Regular.ttf");
  sekuya_font.baseSize = 30;
  rl.GuiSetFont(sekuya_font);



  planets: [dynamic]Planet;

  append(&planets, Planet{
    is_static = true,
    position = rl.Vector3{500, 0, 0},
    velocity = rl.Vector3{0, 0, 0},
    radius = 10,
    color = rl.Color{0, 230, 0, 255},
    mass = 0,
    name = "Select a body",
  });
  camera_focus_body = &planets[0];

  append(&planets, Planet{
    is_static = true,
    position = rl.Vector3{0, 0, 0},
    velocity = rl.Vector3{0, 0, 0},
    radius = 100,
    color = rl.Color{230, 230, 0, 255},
    mass = 1000000,
    name = "Sun"
  });

  append(&planets, Planet{
    is_static = false,
    position = rl.Vector3{400, 0, 0},
    velocity = rl.Vector3{0, 0, 225},
    radius = 9.65,
    color = rl.Color{205, 205, 0, 255},
    mass = 500,
    name = "Venus",
    path_prediction_enabled = true
  });

  append(&planets, Planet{
    is_static = false,
    position = rl.Vector3{600, 0, 0},
    velocity = rl.Vector3{0, 0, 318},
    radius = 10,
    color = rl.Color{0, 255, 0, 255},
    mass = 1000,
    name = "Earth",
    path_prediction_enabled = true
  });



  camera: rl.Camera3D;
  init_camera(&camera);

  for !rl.WindowShouldClose() && !rl.IsKeyDown(.ESCAPE) {
    dt: f32 = rl.GetFrameTime() * simulation_speed_scalar;
    gt: f32 = f32(rl.GetTime());
    mouse_pos = rl.GetMousePosition();

    if !mouse_enabled {
      update_camera(&camera, dt);
    }

    if !mouse_ingui {

      if rl.IsMouseButtonReleased(.LEFT) {
        mouse_enabled = !mouse_enabled;
      }
      if mouse_enabled && rl.IsMouseButtonPressed(.LEFT) {
        ray: rl.Ray;
        collision: rl.RayCollision;
        if !collision.hit {
          ray = rl.GetScreenToWorldRay(mouse_pos, camera);

          for &planet in planets {
            collision = rl.GetRayCollisionSphere(ray, planet.position, planet.radius);
            if collision.hit {
              camera_focus_body = &planet;
              break;
            }
          }
        } else {
          collision.hit = false;
        }
      }

      if mouse_enabled {
        rl.ShowCursor();
      } else {
        rl.HideCursor();
        rl.DisableCursor();
      }
    }

    rl.BeginDrawing();
    rl.ClearBackground({0, 0, 0, 255});

    rl.BeginMode3D(camera);
    rlgl.DisableDepthMask();
    rlgl.DisableBackfaceCulling();
    rl.DrawModel(skybox, camera.position, 1, {255, 255, 255, 255});
    rlgl.EnableBackfaceCulling();
    rlgl.EnableDepthMask();

    for &planet in planets {
      rl.DrawSphereWires(planet.position, planet.radius, 10, 10, planet.color);
      // rl.DrawSphere(planet.position, planet.radius, planet.color);
      if !planet.is_static { // Path prediction

        if simulation_running {
          planet.position += planet.velocity * dt;
        }

        if planet.path_prediction_enabled {
          ghost: Planet = planet;
          for i in 0..<FUTURE_STEPS {
            prevPos: rl.Vector3 = ghost.position;

            for &b in planets {
              if b.position == ghost.position {
                continue;
              }

              d: rl.Vector3 = b.position - ghost.position;
              l: f32 = rl.Vector3Length(d);
              n: rl.Vector3 = d / l;

              f: f32 = GRAVITATIONAL_CONSTANT * ((b.mass * ghost.mass) / l);
              ghost.velocity += n * f * FUTURE_STEPS_DT;
            }
            ghost.position += ghost.velocity * FUTURE_STEPS_DT;

            rl.DrawLine3D(prevPos, ghost.position, {255, 255, 255, 255});

          }
        }

      }


      //Attract other planets towards us
      if simulation_running {
        for &b in planets {
          if b.position == planet.position || b.is_static {
            continue;
          }

          d: rl.Vector3 = planet.position - b.position;
          l: f32 = rl.Vector3Length(d);
          n: rl.Vector3 = d / l;

          f: f32 = GRAVITATIONAL_CONSTANT * ((b.mass * planet.mass) / l);
          b.velocity += n * f * dt;
        }
      }
    }


    rl.EndMode3D();

    rl.DrawRectangleV({gui_rect.x, gui_rect.y} - 5, {gui_rect.width, gui_rect.height} + 10, rl.GetColor(u32(rl.GuiGetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.BACKGROUND_COLOR)))));

    if (mouse_pos.x < gui_rect.x + gui_rect.width &&
        mouse_pos.x + 1 > gui_rect.x &&
        mouse_pos.y < gui_rect.y + gui_rect.height &&
        mouse_pos.y + 1 > gui_rect.y) {
      mouse_ingui = true;
    } else {
      mouse_ingui = false;
    }
    rl.GuiGroupBox(gui_rect, "Controls");
    rl.GuiLabel({30, 30, 380, 50}, camera_focus_body.name);
    rl.GuiSlider({60, 30 + 50, 280, 20}, "VX", rl.TextFormat("%0.2f", camera_focus_body.velocity.x), &camera_focus_body.velocity.x, -800, 800);
    rl.GuiSlider({60, 30 + 50 + 25, 280, 20}, "VY", rl.TextFormat("%0.2f", camera_focus_body.velocity.y), &camera_focus_body.velocity.y, -800, 800);
    rl.GuiSlider({60, 30 + 50 + 50, 280, 20}, "VZ", rl.TextFormat("%0.2f", camera_focus_body.velocity.z), &camera_focus_body.velocity.z, -800, 800);
    rl.GuiSlider({150, 30 + 50 + 90, 200, 20}, "Sim Speed", rl.TextFormat("%0.2f", simulation_speed_scalar), &simulation_speed_scalar, 0.01, 100);
    rl.GuiLabel({60, 30 + 50 + 90 + 25, 200, 20}, rl.TextFormat("X %0.5f", camera_focus_body.position.x));
    rl.GuiLabel({60, 30 + 50 + 90 + 50, 200, 20}, rl.TextFormat("Y %0.5f", camera_focus_body.position.y));
    rl.GuiLabel({60, 30 + 50 + 90 + 75, 200, 20}, rl.TextFormat("Z %0.5f", camera_focus_body.position.z));
    rl.GuiToggle({30, 30 + 50 + 90 + 100, 380, 20}, "Predict path", &camera_focus_body.path_prediction_enabled);
    rl.GuiSlider({150, 30 + 50 + 90 + 125, 200, 20}, "Radius", rl.TextFormat("%0.2f", camera_focus_body.radius), &camera_focus_body.radius, 1, 200);
    rl.GuiSlider({150, 30 + 50 + 90 + 150, 200, 20}, "Mass", rl.TextFormat("%0.2f", camera_focus_body.mass), &camera_focus_body.mass, 0, 20000000);
    
    gui_spawn_rect := rl.Rectangle{
      gui_rect.x + 10,
      gui_rect.y + gui_rect.height - (60 + 60),
      gui_rect.width - 20,
      50
    };

    if rl.GuiButton(gui_spawn_rect, "SPAWN") {
      append(&planets, Planet{
        is_static = false,
        position = rl.Vector3{camera_focus_body.position.x,camera_focus_body.position.y,camera_focus_body.position.z},
        radius = 20,
        color = rl.Color{255, 0, 255, 255},
        mass = 1000,
        name = "Unnamed",
        path_prediction_enabled = true
      });
    }
    
    startstop_button_rec: rl.Rectangle = {
      30,
      (gui_rect.height + gui_rect.y) - 60,
      (gui_rect.x + gui_rect.width) - 40,
      50
    };

    if simulation_running {
      simulation_running = !rl.GuiButton(startstop_button_rec, "STOP SIM");
    } else {
      simulation_running = rl.GuiButton(startstop_button_rec, "RESUME SIM");
    }

    if rl.IsKeyPressed(.SPACE) {
      simulation_running = !simulation_running;
    }

    if rl.IsKeyPressed(.PERIOD) {
      simulation_speed_scalar *= 1.5;
    }
    if rl.IsKeyPressed(.COMMA) {
      simulation_speed_scalar *= 0.666666;
    }
    if rl.IsKeyPressed(.SLASH) {
      simulation_speed_scalar = 1;
    }

    rl.EndDrawing();
  }

  rl.UnloadModel(skybox);
  rl.UnloadTexture(stars_texture);
  rl.UnloadFont(sekuya_font);

  rl.CloseWindow();
}
