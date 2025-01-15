const std = @import("std");

pub export const some_number: f32 = 3.14159;
pub export const num_balls: usize = 100;
const px_per_m = 100;
const collision_impulse = 100.0 * px_per_m;
const max_velocity = 500;

pub extern fn logWasm(msg: [*c]const u8, len: usize) void;

fn wasmLog(
        comptime _: std.log.Level,
        comptime _: @TypeOf(.enum_literal),
        comptime format: []const u8,
        args: anytype,
    ) void  {

    var log_buf: [4096]u8 =undefined;
    const formatted = std.fmt.bufPrint(&log_buf, format, args) catch &log_buf;
    logWasm(formatted.ptr, formatted.len);
}

pub const std_options: std.Options = .{
    .logFn = wasmLog,
};

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    logWasm(msg.ptr, msg.len);
    @trap();
}

pub const globals = struct {
    pub export var ball_radius: f32 = 1.0;
    pub export var container_radius: f32 = 1.0;
    pub export var ball_positions: [num_balls]Vec2 = .{.{1, 1}} ** (num_balls);

    export var ball_velocities: [num_balls]Vec2 = .{Vec2{0, 0}} ** num_balls;
};

pub export fn init(container_radius: f32, ball_radius: f32) void {
    const hello = "hello world";
    logWasm(hello, hello.len);
    globals.ball_radius = ball_radius;
    globals.container_radius = container_radius;

    var height = container_radius * 2 + ball_radius;
    for (0..num_balls) |ball_id| {
        globals.ball_positions[ball_id] = .{ball_radius * 2.0, height};
        height += ball_radius * 2;
    }
}

const Vec2 = @Vector(2, f32);

pub export fn step(delta: f32) void {
    applyAcceleration(delta);
    applyBorderCollision(delta);
    applyBallCollision(delta);
    applyDrag();
    applyVelocity(delta);
}

fn applyDrag() void {
    const air_drag = 0.95;
    for (0..num_balls) |ball_idx| {
        const vel = &globals.ball_velocities[ball_idx];
        vel.* *= @splat(air_drag);
    }
}
fn capVelocities() void {
    for (0..num_balls) |ball_idx| {
        const vel = &globals.ball_velocities[ball_idx];
        const vel_mag = length(vel.*);
        if (vel_mag > max_velocity) {
            vel.* = vel.* * @as(Vec2, @splat(max_velocity / vel_mag));
        }
    }

}
fn applyVelocity(delta: f32) void {
    for (0..num_balls) |ball_idx| {
        const ball = &globals.ball_positions[ball_idx];
        ball.* += @as(Vec2, @splat(delta)) * globals.ball_velocities[ball_idx];
    }
}

fn applyAcceleration(delta: f32) void {
    for (&globals.ball_velocities) |*vel| {
        vel[1] -= delta * 9.8 * px_per_m;
    }
}

fn length(a: Vec2) f32 {
    const c2 = a[0] * a[0]  + a[1] * a[1];
    return @sqrt(c2);
}

fn dot(a: Vec2, b: Vec2) f32 {
    return a[0] * b[0] + a[1] * b[1];
}

fn applyBallCollision(delta: f32) void {
    const dist_of_minimal_intersection = globals.ball_radius * 2;

    for (0..num_balls) |a_idx| {
        const a_pos = globals.ball_positions[a_idx];
        for (a_idx + 1..num_balls) |b_idx| {
            const b_pos = globals.ball_positions[b_idx];
            const b_rel_a = b_pos - a_pos;

            const dist = length(b_rel_a);
            const intersection_normal = b_rel_a / Vec2{dist, dist};

            const intersection_amount = dist_of_minimal_intersection - dist;

            if (intersection_amount <= 0) {
                continue;
            }

            const a_velocity = &globals.ball_velocities[a_idx];
            const b_velocity = &globals.ball_velocities[b_idx];

            const b_vel_rel_a = b_velocity.* - a_velocity.*;

            const b_rel_a_proj = dot(b_vel_rel_a, intersection_normal);

            const dampen_factor: f32 = 0.7;
            var a_impulse = -intersection_normal * @as(Vec2, @splat(intersection_amount / delta / 2.0 - b_rel_a_proj / 2.0));
            a_impulse *= Vec2{dampen_factor, dampen_factor};
            const b_impulse = -a_impulse;

            a_velocity.* += a_impulse;
            b_velocity.* += b_impulse;

            //globals.ball_positions[a_idx] += a_movement;
            //globals.ball_positions[b_idx] += b_movement;
        }
    }
}

fn applyBorderCollision(delta: f32) void {
    const container_center = Vec2{0, globals.container_radius};
    const dist_of_minimal_intersection = globals.container_radius - globals.ball_radius;

    for (&globals.ball_positions, 0..) |pos, ball_idx| {

        var towards_center = container_center - pos;
        const center_dist = length(towards_center);
        towards_center /= @splat(center_dist);

        // How far inside are we
        const intersection_amount = center_dist - dist_of_minimal_intersection;
        if (intersection_amount > globals.ball_radius * 2 or intersection_amount < 0) {
            continue;
        }

        const ball_vel = &globals.ball_velocities[ball_idx];

        const vel_proj = dot(ball_vel.*, towards_center);

        if (vel_proj >= 0.0) {
            continue;
        }

        const impulse = towards_center * @as(Vec2, @splat(intersection_amount / delta - vel_proj));
        std.log.info("impulse: {any}, intersection_amount: {d}, delta: {d}, vel_proj: {d}, vel: {d}", .{impulse, intersection_amount, delta, vel_proj, ball_vel.*});

        ball_vel.* += impulse;
        std.log.info("new ball velocity: {any}", .{ball_vel.*});
        //globals.ball_positions[ball_idx] += towards_center * @as(Vec2, @splat(intersection_amount));
    }
}

pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}
