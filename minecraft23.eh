<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Minecraft 2D - All Mobs Update</title>
    <style>
        body { margin: 0; overflow: hidden; background: #222; font-family: monospace; }
        canvas { display: block; background: #87CEEB; }
        #ui { position: absolute; top: 10px; left: 10px; color: white; font-size: 20px; text-shadow: 2px 2px 0 #000; pointer-events: none; }
        #hotbar { 
            position: absolute; bottom: 10px; left: 50%; transform: translateX(-50%);
            display: flex; gap: 5px; background: rgba(0,0,0,0.5); padding: 5px; border-radius: 5px;
        }
        .slot { width: 40px; height: 40px; border: 2px solid #555; display: flex; align-items: center; justify-content: center; font-weight: bold; color: white; background: #333; cursor: pointer;}
        .active { border-color: white; background: #555; }
    </style>
</head>
<body>

<div id="ui">
    Minecraft 2D: Mob Update<br>
    <small>WASD: Move | Click: Mine/Attack | 1-5: Items</small><br>
    <small style="color:yellow">Mobs added: Zombies, Creepers, Pigs, Breeze</small>
</div>

<div id="hotbar">
    <div class="slot active">Grass</div>
    <div class="slot">Wood</div>
    <div class="slot">Stone</div>
    <div class="slot">Tuff</div>
    <div class="slot" style="color:cyan">MACE</div>
</div>

<canvas id="game"></canvas>

<script>
/* --- CONFIGURATION --- */
const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');

canvas.width = window.innerWidth;
canvas.height = window.innerHeight;

const BLOCK_SIZE = 40;
const CHUNK_WIDTH = 120; 
const CHUNK_HEIGHT = 60; 
const GRAVITY = 0.5;

// Colors
const COLORS = {
    0: null, 1: '#228B22', 2: '#8B4513', 3: '#777', 4: '#333', 
    5: '#654321', 6: '#228B22', 7: '#4A4A4A', 8: '#e67e22'
};

/* --- GAME STATE --- */
let world = [];
let camera = { x: 0, y: 0 };
let inventory = [1, 5, 3, 7, 'mace'];
let selectedSlot = 0;
let mobs = [];

let player = {
    x: CHUNK_WIDTH * BLOCK_SIZE / 2, y: 0, w: 20, h: 36, vx: 0, vy: 0, grounded: false,
    health: 100
};

/* --- GENERATION --- */
function init() {
    // 1. Terrain
    for (let x = 0; x < CHUNK_WIDTH; x++) {
        world[x] = [];
        let h = 20 + Math.floor(Math.sin(x / 8) * 5);
        for (let y = 0; y < CHUNK_HEIGHT; y++) {
            if (y < h) world[x][y] = 0; // Air
            else if (y === h) world[x][y] = 1; // Grass
            else if (y > h && y < h + 5) world[x][y] = 2; // Dirt
            else if (y === CHUNK_HEIGHT - 1) world[x][y] = 4; // Bedrock
            else world[x][y] = 3; // Stone
        }
        // Trees
        if (x % 10 === 0 && x > 5 && x < CHUNK_WIDTH - 5) createTree(x, h);
    }

    // 2. Spawn Mobs
    for (let i = 0; i < 5; i++) spawnMob('zombie');
    for (let i = 0; i < 3; i++) spawnMob('creeper');
    for (let i = 0; i < 5; i++) spawnMob('pig');
    spawnMob('breeze');
}

function createTree(x, y) {
    world[x][y-1] = 5; world[x][y-2] = 5; world[x][y-3] = 5; // Trunk
    world[x-1][y-3] = 6; world[x+1][y-3] = 6; world[x][y-4] = 6; // Leaves
}

/* --- MOB SYSTEM --- */
function spawnMob(type) {
    let x = (Math.random() * (CHUNK_WIDTH - 20) + 10) * BLOCK_SIZE;
    let y = 0; // Drop from sky
    let color = 'white';
    let ai = 'passive';

    if (type === 'zombie') { color = '#2E8B57'; ai = 'hostile'; }
    if (type === 'creeper') { color = '#006400'; ai = 'creeper'; }
    if (type === 'pig') { color = '#FFC0CB'; ai = 'passive'; }
    if (type === 'breeze') { color = '#A020F0'; ai = 'jumper'; }

    mobs.push({
        type: type, x: x, y: y, w: 30, h: 30, vx: 0, vy: 0, 
        color: color, ai: ai, health: 3, dead: false, flashTimer: 0
    });
}

function updateMobs() {
    mobs.forEach(mob => {
        if (mob.dead) return;

        // Gravity
        mob.vy += GRAVITY;
        mob.y += mob.vy;
        checkCollision(mob, 'y');

        // AI Logic
        let dist = player.x - mob.x;
        
        if (mob.ai === 'hostile') {
            // Chase Player
            if (Math.abs(dist) < 400) { // Aggro range
                mob.vx = dist > 0 ? 2 : -2;
                // Jump up blocks
                let wallX = dist > 0 ? Math.floor((mob.x + mob.w + 5)/BLOCK_SIZE) : Math.floor((mob.x - 5)/BLOCK_SIZE);
                let wallY = Math.floor((mob.y + mob.h - 5)/BLOCK_SIZE);
                if (world[wallX] && world[wallX][wallY] !== 0 && mob.grounded) mob.vy = -7;
            } else {
                mob.vx = 0;
            }
        } 
        else if (mob.ai === 'creeper') {
            // Creeper Logic
            if (Math.abs(dist) < 400) {
                if (Math.abs(dist) < 40) {
                    mob.vx = 0; // Stop to explode
                    mob.flashTimer++;
                    if (mob.flashTimer > 30) {
                        // EXPLODE (Visual only for safety, pushes player)
                        player.vy = -10;
                        player.vx = dist > 0 ? 10 : -10;
                        mob.dead = true;
                    }
                } else {
                    mob.vx = dist > 0 ? 1.5 : -1.5;
                    mob.flashTimer = 0;
                    // Jump check
                    let wallX = dist > 0 ? Math.floor((mob.x + mob.w + 5)/BLOCK_SIZE) : Math.floor((mob.x - 5)/BLOCK_SIZE);
                    let wallY = Math.floor((mob.y + mob.h - 5)/BLOCK_SIZE);
                    if (world[wallX] && world[wallX][wallY] !== 0 && mob.grounded) mob.vy = -7;
                }
            }
        }
        else if (mob.ai === 'passive') {
            // Random wander
            if (Math.random() < 0.02) mob.vx = Math.random() < 0.5 ? -1 : 1;
        }
        else if (mob.ai === 'jumper') {
            // Breeze jumping
            if (mob.grounded) {
                mob.vy = -12;
                mob.vx = (Math.random() - 0.5) * 15;
            }
        }

        mob.x += mob.vx;
        checkCollision(mob, 'x');

        // Kill mob if it falls out of world
        if (mob.y > CHUNK_HEIGHT * BLOCK_SIZE) mob.dead = true;
    });
}

/* --- PHYSICS --- */
function checkCollision(entity, axis) {
    let startX = Math.floor(entity.x / BLOCK_SIZE);
    let endX = Math.floor((entity.x + entity.w) / BLOCK_SIZE);
    let startY = Math.floor(entity.y / BLOCK_SIZE);
    let endY = Math.floor((entity.y + entity.h) / BLOCK_SIZE);

    entity.grounded = false;
    for (let x = startX; x <= endX; x++) {
        for (let y = startY; y <= endY; y++) {
            if (world[x] && world[x][y]) {
                if (axis === 'x') {
                    if (entity.vx > 0) entity.x = x * BLOCK_SIZE - entity.w - 0.1;
                    if (entity.vx < 0) entity.x = (x + 1) * BLOCK_SIZE + 0.1;
                    entity.vx = 0;
                } else {
                    if (entity.vy > 0) { entity.y = y * BLOCK_SIZE - entity.h - 0.1; entity.grounded = true; }
                    if (entity.vy < 0) entity.y = (y + 1) * BLOCK_SIZE + 0.1;
                    entity.vy = 0;
                }
            }
        }
    }
}

/* --- CONTROLS --- */
let keys = {};
window.onkeydown = e => {
    keys[e.code] = true;
    if (e.key >= 1 && e.key <= 5) {
        selectedSlot = e.key - 1;
        updateUI();
    }
};
window.onkeyup = e => keys[e.code] = false;

let mouse = { x: 0, y: 0, click: false };
window.onmousemove = e => { mouse.x = e.clientX; mouse.y = e.clientY; };
window.onmousedown = e => {
    mouse.click = true;
    // Attack Mobs
    if (inventory[selectedSlot] === 'mace') {
        let mx = mouse.x + camera.x;
        let my = mouse.y + camera.y;
        mobs.forEach(mob => {
            if (!mob.dead && mx > mob.x && mx < mob.x + mob.w && my > mob.y && my < mob.y + mob.h) {
                mob.health--;
                mob.vy = -5; // Knockback
                mob.vx = player.x < mob.x ? 5 : -5;
                if (mob.health <= 0) mob.dead = true;
            }
        });
    }
    // Block Interaction
    else {
        let bx = Math.floor((mouse.x + camera.x) / BLOCK_SIZE);
        let by = Math.floor((mouse.y + camera.y) / BLOCK_SIZE);
        if (world[bx] && world[bx][by] !== undefined) {
             if (e.button === 0) world[bx][by] = 0; // Break
             if (e.button === 2 && world[bx][by] === 0) world[bx][by] = inventory[selectedSlot]; // Place
        }
    }
};
window.onmouseup = e => mouse.click = false;
window.oncontextmenu = e => e.preventDefault();

function updateUI() {
    document.querySelectorAll('.slot').forEach((el, i) => {
        el.classList.toggle('active', i === selectedSlot);
    });
}

/* --- MAIN LOOP --- */
function loop() {
    // Player Move
    if (keys['KeyA']) player.vx = -5;
    if (keys['KeyD']) player.vx = 5;
    if (!keys['KeyA'] && !keys['KeyD']) player.vx = 0;
    if (keys['Space'] && player.grounded) player.vy = -10;

    player.vy += GRAVITY;
    player.y += player.vy;
    checkCollision(player, 'y');
    player.x += player.vx;
    checkCollision(player, 'x');
    
    // Bounds
    if (player.y > CHUNK_HEIGHT * BLOCK_SIZE) { player.x = 200; player.y = 0; }

    updateMobs();

    // Camera
    camera.x = player.x - canvas.width / 2;
    camera.y = player.y - canvas.height / 2;

    draw();
    requestAnimationFrame(loop);
}

function draw() {
    // Sky
    ctx.fillStyle = '#87CEEB';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Blocks
    let startX = Math.floor(camera.x / BLOCK_SIZE);
    let endX = startX + (canvas.width / BLOCK_SIZE) + 2;
    let startY = Math.floor(camera.y / BLOCK_SIZE);
    let endY = startY + (canvas.height / BLOCK_SIZE) + 2;

    for (let x = startX; x < endX; x++) {
        for (let y = startY; y < endY; y++) {
            if (world[x] && world[x][y]) {
                ctx.fillStyle = COLORS[world[x][y]];
                ctx.fillRect(x*BLOCK_SIZE - camera.x, y*BLOCK_SIZE - camera.y, BLOCK_SIZE, BLOCK_SIZE);
                ctx.strokeStyle = "rgba(0,0,0,0.1)";
                ctx.strokeRect(x*BLOCK_SIZE - camera.x, y*BLOCK_SIZE - camera.y, BLOCK_SIZE, BLOCK_SIZE);
            }
        }
    }

    // Player
    ctx.fillStyle = 'blue';
    ctx.fillRect(player.x - camera.x, player.y - camera.y, player.w, player.h);

    // Mobs
    mobs.forEach(mob => {
        if (mob.dead) return;
        ctx.fillStyle = (mob.ai === 'creeper' && mob.flashTimer % 10 > 5) ? 'white' : mob.color;
        ctx.fillRect(mob.x - camera.x, mob.y - camera.y, mob.w, mob.h);
        
        // Face
        ctx.fillStyle = 'black';
        ctx.fillRect(mob.x - camera.x + 5, mob.y - camera.y + 5, 5, 5);
        ctx.fillRect(mob.x - camera.x + 20, mob.y - camera.y + 5, 5, 5);
    });

    // Weapon
    if (inventory[selectedSlot] === 'mace') {
        ctx.fillStyle = 'cyan';
        ctx.fillRect(player.x - camera.x + 10, player.y - camera.y + 10, 10, 20);
    }
}

init();
loop();
window.onresize = () => { canvas.width = window.innerWidth; canvas.height = window.innerHeight; };
</script>
</body>
</html>yhwa
