/** @type Float32Array|null */
var ball_positions = null;
/** @type CanvasRenderingContext2D|null */
var renderCtx = null;
/** @type WebAssembly.WebAssemblyInstantiatedSource|null */
var wasm = null;
const container_radius = 200;

function wasmMemory() {
    const wasm_memory = wasm.instance.exports.memory;
    return wasm_memory.buffer;
}

function wasmDataView() {
    return new DataView(wasmMemory());
}

function ballRadius() {
    const memory_view = wasmDataView();
    return memory_view.getFloat32(wasm.instance.exports.ball_radius, true);
}

function numBalls() {
    const memory_view = wasmDataView();
    return memory_view.getUint32(wasm.instance.exports.num_balls, true);
}

function drawBall(x, y)  {
    renderCtx.fillStyle = "red";
    renderCtx.beginPath();
    renderCtx.arc(x, y, ballRadius(), 0, 2 * Math.PI);
    renderCtx.fill();

    renderCtx.strokeStyle = "white";
    renderCtx.lineWidth = 5;
    renderCtx.beginPath();
    renderCtx.arc(x, y, ballRadius() - 2.5, 0, 2 * Math.PI);
    renderCtx.stroke();
}

function renderFrame() {
    renderCtx.fillStyle = "black";
    renderCtx.fillRect(0, 0, renderCtx.canvas.width, renderCtx.canvas.height);

    renderCtx.strokeStyle = "white";
    renderCtx.lineWidth = 5;
    renderCtx.beginPath();
    renderCtx.arc(renderCtx.canvas.width / 2.0, renderCtx.canvas.height - container_radius, container_radius, 0, 2 * Math.PI);
    renderCtx.stroke();

    const num_balls = numBalls();
    for (let i = 0; i < num_balls; ++i) {
        const x = ball_positions[i * 2] + renderCtx.canvas.width / 2;
        const y = renderCtx.canvas.height - ball_positions[i * 2 + 1]
        drawBall(x, y);
    }

}

function logWasm(msg, len) {
    const msg_data = new Uint8Array(wasmMemory(), msg, len);
    const decoder = new TextDecoder()
    const msg_s = decoder.decode(msg_data);
    console.log(msg_s);
}

var last = window.performance.now()
var last_step = window.performance.now();

function step() {
    const now = window.performance.now();
    const step_len_ms = 1;
    last = now;
    while (last_step < last) {
        wasm.instance.exports.step(step_len_ms / 1000.0);
        last_step += step_len_ms;
    }
    renderFrame();
}

async function init() {
    /** @type HTMLCanvasElement */
    const canvas = document.getElementById("canvas");
    renderCtx = canvas.getContext("2d");

    renderCtx.fillStyle = "black";
    renderCtx.fillRect(0, 0, canvas.width, canvas.height);

    //drawBall(canvas.width / 2, canvas.height / 2, 10);

    wasm = await WebAssembly.instantiateStreaming(fetch("zig-out/bin/module.wasm"), {
        env: {
            logWasm: logWasm,
        }
    });
    /** @type WebAssembly.Memory */
    const wasm_memory = wasm.instance.exports.memory;
    const memory = wasm_memory.buffer;
    const memory_view = new DataView(memory);
    const num_balls = memory_view.getUint32(wasm.instance.exports.num_balls, true);
    ball_positions = new Float32Array(memory, wasm.instance.exports.ball_positions, num_balls * 2 * 4);

    wasm.instance.exports.init(container_radius, 20.0);

    renderFrame();
    window.setInterval(step, 30);
}

window.onload = init;
