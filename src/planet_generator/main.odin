package main;
import "core:fmt";
import rl "vendor:raylib";
import rlgl "vendor:raylib/rlgl";
import rand "core:math/rand";
import noise "core:math/noise";

camera_zoom_factor: f32 = 10;

update_camera :: proc(camera: ^rl.Camera, dt: f32) {
    rl.UpdateCamera(camera, .THIRD_PERSON);
    scroll: f32 = -rl.GetMouseWheelMove() * dt * 60 * 0.05;
    camera_dir: rl.Vector3 = camera.position;
    camera_len: f32 = rl.Vector3Length(camera_dir);
    normalized_camera_dir: rl.Vector3 = camera_dir / camera_len;
    zoom_factor: f32 = 1 + (camera_len / camera_zoom_factor);
    camera.position = normalized_camera_dir * (camera_len + scroll * zoom_factor);
}

mouse_enabled: bool = false;

regenerate_planet :: proc(model: ^rl.Model) {
  fmt.printf("Number of meshes %i \n", model.meshCount);
  if model.meshCount < 1 {
    fmt.println("ERROR modifying a model with no mesh");
    return;
  }

  mesh: rl.Mesh = model.meshes[0];

  for i in 0..<mesh.vertexCount {
    x: f32 = mesh.vertices[i*3];
    y: f32 = mesh.vertices[i*3+1];
    z: f32 = mesh.vertices[i*3+2];
    leng: f32 = rl.Vector3Length({x, y, z});
    norm: rl.Vector3 = {x, y, z} / leng;
    final: rl.Vector3 = norm * (leng + noise.noise_2d(100, noise.Vec2{f64(i) * 0.001, 0}));
    mesh.vertices[i*3] += final.x;
    mesh.vertices[i*3+1] += final.y;
    mesh.vertices[i*3+2] += final.z;
  }

  rl.UpdateMeshBuffer(mesh, 0, mesh.vertices, mesh.vertexCount * size_of(f32) * 3, 0);
}

main :: proc() {
  rl.InitWindow(1500, 900, "Planet creation tool");
  rl.SetTargetFPS(60);

  rl.DisableCursor();

  camera: rl.Camera3D;
  camera.position = {0, 0, -10};
  camera.target = {0, 0, 0};
  camera.up = {0, 1, 0.001};
  camera.fovy = 65;
  camera.projection = .PERSPECTIVE;

  base: rl.Model = rl.LoadModel("../../res/planet_base.obj");

  for !rl.WindowShouldClose() {
    dt: f32 = rl.GetFrameTime();
    if !mouse_enabled {
      update_camera(&camera, dt);
    }

    if rl.IsMouseButtonReleased(.LEFT) {
      mouse_enabled = !mouse_enabled;
      if mouse_enabled {
        rl.EnableCursor();
      } else {
        rl.DisableCursor();
      }
    }

    rl.BeginDrawing();
    rl.ClearBackground({0, 0, 0, 255});

    rl.BeginMode3D(camera);
    rlgl.DisableBackfaceCulling();

    rl.DrawModel(base, {0, 0, 0}, 1, {255, 255, 255, 255});

    rl.EndMode3D();

    rl.EndDrawing();

    if rl.GuiButton({10, 10, 100, 50}, "Randomize") {
      regenerate_planet(&base);
    }
  }

  rl.UnloadModel(base);
  rl.CloseWindow();
}
