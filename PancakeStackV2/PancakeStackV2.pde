// 팬케이크 쌓기 게임 v2 - Processing
// - 마디(뼈대)로 이루어진 소프트바디 팬케이크: 날아가며 휘고, 착지하면 가장자리가 축 늘어짐
// - 꾹 누르면 프라이팬이 힘에 맞춰 위아래로 출렁이고, 놓으면 위로 휙 튕겨 올림

final int READY = 0, CHARGING = 1, TOSSING = 2, FLYING = 3, FALLING = 4, GAMEOVER = 5;
int state;

float gravity = 0.5;

// ---------- 팬케이크 뼈대 설정 (여기 숫자를 바꿔가며 느낌을 조절해보세요) ----------
final int N = 11;     // 뼈대 마디 수
float SEG = 9;        // 마디 간격 (팬케이크 너비 = SEG * (N-1))
float T = 14;         // 두께
float BEND = 0.08;    // 굽힘 강성: 낮을수록 흐물흐물, 높을수록 빳빳
float AIR = 0.04;     // 공중에서 공기 저항으로 휘는 정도
int ITER = 10;        // 물리 계산 반복 횟수 (높을수록 단단하고 안정적)

// ---------- 프라이팬 (화면 고정) ----------
float panX = 120, panY = 600, panHalf = 50;
float panDY = 0, panAng = 0;          // 팬의 위아래 위치 / 기울기
float tossStartDY, tossStartAng;
int tossFrame;
final int TOSS_N = 6;                 // 팬을 튕겨 올리는 프레임 수

// ---------- 접시 (월드 좌표) ----------
float plateX = 400, plateY = 650, plateW = 130;

// ---------- 힘 게이지 ----------
float power, minPower = 5, maxPower = 20, powerDir = 1;
float launchAngle = radians(60);

Pancake cake;
ArrayList<PVector[]> settled = new ArrayList<PVector[]>();  // 쌓인 팬케이크 모양
float[] hf;        // 높이맵: x 위치별로 가장 위에 있는 표면의 y
float stackTop;    // 탑 꼭대기 높이
float camY;
int best = 0;
boolean touched;
int stillFrames, unsupportedFrames, fallFrames;

void setup() {
  size(500, 700);
  textAlign(CENTER, CENTER);
  strokeJoin(ROUND);
  resetGame();
}

void resetGame() {
  settled.clear();
  hf = new float[width];
  for (int x = 0; x < width; x++) hf[x] = 1e9;
  for (int x = int(plateX - plateW/2); x <= int(plateX + plateW/2); x++) {
    if (x >= 0 && x < width) hf[x] = plateY;
  }
  stackTop = plateY;
  camY = 0;
  panDY = 0;
  panAng = 0;
  spawnCake();
}

void spawnCake() {
  cake = new Pancake(panX, panY + panDY - 3 - T/2 - camY);
  power = minPower;
  powerDir = 1;
  state = READY;
}

float hfAt(float x) {
  int ix = round(x);
  if (ix < 0 || ix >= width) return 1e9;
  return hf[ix];
}

// 뼈대의 i번째 마디에서 표면의 법선(바깥 방향)
PVector normalOf(PVector[] p, int i) {
  PVector a = p[max(i - 1, 0)], b = p[min(i + 1, N - 1)];
  PVector t = PVector.sub(b, a);
  t.normalize();
  return new PVector(t.y, -t.x);
}

// ================= 소프트바디 팬케이크 =================
class Pancake {
  PVector[] p = new PVector[N];    // 현재 위치
  PVector[] pp = new PVector[N];   // 이전 위치 (Verlet 적분)
  boolean[] contact = new boolean[N];
  boolean friction = true;

  Pancake(float cx, float cy) {
    for (int i = 0; i < N; i++) {
      float x = cx + (i - (N - 1) / 2.0) * SEG;
      p[i] = new PVector(x, cy);
      pp[i] = p[i].copy();
    }
  }

  void step(boolean air) {
    PVector[] v = new PVector[N];
    for (int i = 0; i < N; i++) v[i] = PVector.sub(p[i], pp[i]);

    if (air) {
      // 표면에 수직인 방향으로 공기 저항 → 가장자리가 뒤처지며 휨
      // (평균을 빼서 전체 비행 궤적은 바뀌지 않게 함)
      PVector[] f = new PVector[N];
      PVector mean = new PVector();
      for (int i = 0; i < N; i++) {
        PVector n = normalOf(p, i);
        f[i] = PVector.mult(n, -AIR * v[i].dot(n));
        mean.add(f[i]);
      }
      mean.div(N);
      for (int i = 0; i < N; i++) v[i].add(f[i]).sub(mean);
    }

    for (int i = 0; i < N; i++) {
      pp[i].set(p[i]);
      p[i].add(v[i]);
      p[i].y += gravity;
      contact[i] = false;
    }
  }

  void solveConstraints() {
    for (int i = 0; i < N - 1; i++) solveDist(i, i + 1, SEG, 1.0);       // 길이 유지
    for (int i = 0; i < N - 2; i++) solveDist(i, i + 2, SEG * 2, BEND);  // 굽힘 저항
  }

  void solveDist(int a, int b, float rest, float k) {
    PVector d = PVector.sub(p[b], p[a]);
    float len = d.mag();
    if (len < 0.0001) return;
    d.mult((len - rest) / len * 0.5 * k);
    p[a].add(d);
    p[b].sub(d);
  }

  // 접시와 쌓인 팬케이크 위에 착지
  void collideHeight() {
    for (int i = 0; i < N; i++) {
      float h = hfAt(p[i].x);
      if (p[i].y + T/2 > h && pp[i].y + T/2 <= h + 6) {
        p[i].y = h - T/2;
        contact[i] = true;
      }
    }
  }

  void applyFriction() {
    for (int i = 0; i < N; i++) {
      if (!contact[i]) continue;
      if (friction) pp[i].x = lerp(pp[i].x, p[i].x, 0.6);
      pp[i].y = p[i].y;  // 튕기지 않음
    }
  }

  PVector com() {
    PVector c = new PVector();
    for (int i = 0; i < N; i++) c.add(p[i]);
    return c.div(N);
  }

  float maxSpeed() {
    float m = 0;
    for (int i = 0; i < N; i++) m = max(m, PVector.dist(p[i], pp[i]));
    return m;
  }

  PVector[] snapshot() {
    PVector[] s = new PVector[N];
    for (int i = 0; i < N; i++) s[i] = p[i].copy();
    return s;
  }
}

// 기울어진 프라이팬 바닥과 충돌
void collidePan(Pancake c) {
  float cx = panX, cy = panY + panDY - 3 - camY;
  float ca = cos(panAng), sa = sin(panAng);
  for (int i = 0; i < N; i++) {
    float dx = c.p[i].x - cx, dy = c.p[i].y - cy;
    float lx = dx * ca + dy * sa;      // 팬 기준 좌표로 변환
    float ly = -dx * sa + dy * ca;
    if (ly > -T/2) { ly = -T/2; c.contact[i] = true; }
    lx = constrain(lx, -panHalf, panHalf);
    c.p[i].x = cx + lx * ca - ly * sa;
    c.p[i].y = cy + lx * sa + ly * ca;
  }
}

// ================= 게임 진행 =================
void draw() {
  background(255, 244, 225);
  updateGame();

  camY = lerp(camY, max(0, 330 - stackTop), 0.08);

  drawPan();

  pushMatrix();
  translate(0, camY);
  drawPlate();
  for (PVector[] s : settled) drawCake(s);
  drawCake(cake.p);
  drawTable();   // 테이블을 맨 앞에 그려서 떨어진 팬케이크가 뒤로 사라지게
  popMatrix();

  if (state == CHARGING) drawGauge();
  drawUI();
}

void updateGame() {
  // ----- 프라이팬 움직임 -----
  if (state == CHARGING) {
    power += powerDir * 0.3;
    if (power > maxPower) { power = maxPower; powerDir = -1; }
    if (power < minPower) { power = minPower; powerDir = 1; }
    float t = (power - minPower) / (maxPower - minPower);
    // 힘이 셀수록 팬이 깊이 내려가고 살짝 떨림
    panDY = lerp(panDY, t * 22 + random(-1.5, 1.5) * t, 0.3);
    panAng = lerp(panAng, 0.12 * t, 0.3);
  } else if (state == TOSSING) {
    tossFrame++;
    float e = sq(tossFrame / (float) TOSS_N);   // 점점 빨라지며 휙!
    panDY = lerp(tossStartDY, -40, e);
    panAng = lerp(tossStartAng, -0.35, e);
  } else {
    panDY = lerp(panDY, 0, 0.15);
    panAng = lerp(panAng, 0, 0.15);
  }

  // ----- 팬케이크 물리 -----
  if (state == READY || state == CHARGING || state == TOSSING) {
    cake.step(false);
    for (int k = 0; k < ITER; k++) {
      cake.solveConstraints();
      collidePan(cake);
    }
    cake.applyFriction();
    if (state == TOSSING && tossFrame >= TOSS_N) launch();
  }
  else if (state == FLYING || state == FALLING) {
    cake.step(true);
    for (int k = 0; k < ITER; k++) {
      cake.solveConstraints();
      cake.collideHeight();
    }
    cake.applyFriction();

    if (state == FLYING) checkLanding();
    else if (++fallFrames > 150) state = GAMEOVER;

    if (cake.com().y + camY > height + 60) state = GAMEOVER;
  }
}

void launch() {
  PVector c = cake.com();
  float lvx = power * cos(launchAngle);
  float lvy = -power * sin(launchAngle);

  // 탑 꼭대기에 닿을 때까지 걸리는 시간을 계산해서 딱 한 바퀴 반(180°) 뒤집히게
  float target = stackTop - T/2;
  float disc = lvy * lvy - 2 * gravity * (c.y - target);
  float t = (disc > 0) ? (-lvy + sqrt(disc)) / gravity : -2 * lvy / gravity;
  float omega = PI / max(t, 10);

  float bow = 2 + power * 0.15;  // 가운데가 먼저 튀어 올라 가장자리가 처지는 정도
  for (int i = 0; i < N; i++) {
    float dx = cake.p[i].x - c.x, dy = cake.p[i].y - c.y;
    float u = (i - (N - 1) / 2.0) / ((N - 1) / 2.0);
    float vx = lvx - omega * dy;
    float vy = lvy + omega * dx + bow * (u * u - 0.4);
    cake.pp[i].set(cake.p[i].x - vx, cake.p[i].y - vy);
  }
  touched = false;
  stillFrames = 0;
  unsupportedFrames = 0;
  state = FLYING;
}

void checkLanding() {
  int cnt = 0;
  float minX = 1e9, maxX = -1e9;
  for (int i = 0; i < N; i++) {
    if (cake.contact[i]) {
      cnt++;
      minX = min(minX, cake.p[i].x);
      maxX = max(maxX, cake.p[i].x);
    }
  }
  if (cnt > 0) touched = true;
  if (!touched) return;

  // 무게중심이 받치고 있는 부분 위에 있어야 안정
  PVector c = cake.com();
  boolean supported = cnt >= 2 && c.x >= minX - 2 && c.x <= maxX + 2;
  unsupportedFrames = supported ? 0 : unsupportedFrames + 1;

  if (unsupportedFrames > 12) {
    float dir = (cnt > 0 && c.x < (minX + maxX) / 2) ? -1 : 1;
    cake.friction = false;
    for (int i = 0; i < N; i++) cake.pp[i].x -= dir * 1.5;
    fallFrames = 0;
    state = FALLING;
    return;
  }

  stillFrames = (cake.maxSpeed() < 0.15) ? stillFrames + 1 : 0;
  if (supported && stillFrames > 20) settle();
}

void settle() {
  PVector[] s = cake.snapshot();
  settled.add(s);
  // 높이맵에 새 팬케이크 윗면을 기록
  for (int i = 0; i < N - 1; i++) {
    PVector a = s[i], b = s[i + 1];
    int x0 = floor(min(a.x, b.x)), x1 = ceil(max(a.x, b.x));
    for (int x = x0; x <= x1; x++) {
      if (x < 0 || x >= width) continue;
      float t = abs(b.x - a.x) < 0.001 ? 0.5 : constrain((x - a.x) / (b.x - a.x), 0, 1);
      hf[x] = min(hf[x], lerp(a.y, b.y, t) - T/2);
    }
    stackTop = min(stackTop, a.y - T/2);
  }
  stackTop = min(stackTop, s[N - 1].y - T/2);
  best = max(best, settled.size());
  spawnCake();
}

void mousePressed() {
  if (state == GAMEOVER) { resetGame(); return; }
  if (state == READY) {
    state = CHARGING;
    power = minPower;
    powerDir = 1;
  }
}

void mouseReleased() {
  if (state == CHARGING) {
    tossFrame = 0;
    tossStartDY = panDY;
    tossStartAng = panAng;
    state = TOSSING;
  }
}

// ================= 그리기 =================
void drawCake(PVector[] p) {
  PVector[] n = new PVector[N];
  for (int i = 0; i < N; i++) n[i] = normalOf(p, i);
  float h = T / 2;

  // 몸통: 뼈대를 따라 두께를 입힌 다각형
  noStroke();
  fill(242, 198, 118);
  beginShape();
  for (int i = 0; i < N; i++) vertex(p[i].x + n[i].x * h, p[i].y + n[i].y * h);
  for (int i = N - 1; i >= 0; i--) vertex(p[i].x - n[i].x * h, p[i].y - n[i].y * h);
  endShape(CLOSE);
  ellipse(p[0].x, p[0].y, T, T);
  ellipse(p[N - 1].x, p[N - 1].y, T, T);

  // 노릇하게 구워진 면 (처음엔 아래쪽 → 뒤집히면 위로 올라옴)
  noFill();
  stroke(180, 108, 40);
  strokeWeight(4);
  beginShape();
  for (int i = 0; i < N; i++) vertex(p[i].x - n[i].x * (h - 2), p[i].y - n[i].y * (h - 2));
  endShape();

  // 하이라이트
  stroke(255, 232, 175);
  strokeWeight(2);
  beginShape();
  for (int i = 2; i < N - 2; i++) vertex(p[i].x + n[i].x * (h - 2.5), p[i].y + n[i].y * (h - 2.5));
  endShape();
  noStroke();
}

void drawPan() {
  pushMatrix();
  translate(panX, panY + panDY);
  rotate(panAng);
  noStroke();
  fill(45);
  rect(-120, -4, 70, 10, 4);    // 손잡이
  ellipse(0, 0, 110, 26);       // 몸체
  fill(75);
  ellipse(0, -3, 96, 18);       // 안쪽
  popMatrix();
}

void drawPlate() {
  noStroke();
  fill(190);
  ellipse(plateX, plateY + 7, plateW + 20, 22);
  fill(250);
  ellipse(plateX, plateY + 2, plateW, 16);
}

void drawTable() {
  noStroke();
  fill(205, 160, 115);
  rect(-10, plateY + 14, width + 20, 2000);
}

void drawGauge() {
  float t = (power - minPower) / (maxPower - minPower);
  float gx = panX - 50, gy = panY - 80, gw = 100, gh = 12;
  noStroke();
  fill(0, 40);
  rect(gx, gy, gw, gh, 6);
  fill(lerpColor(color(90, 200, 90), color(230, 60, 50), t));
  rect(gx, gy, gw * t, gh, 6);
}

void drawUI() {
  fill(90, 50, 20);
  textSize(56);
  text(settled.size(), width/2, 60);
  textSize(16);
  text("BEST " + best, width/2, 105);

  if (state == READY && settled.isEmpty()) {
    text("Hold to charge, release to flip!", width/2, 160);
  }
  if (state == GAMEOVER) {
    fill(0, 120);
    rect(0, 0, width, height);
    fill(255);
    textSize(48);
    text("GAME OVER", width/2, height/2 - 30);
    textSize(20);
    text("Stacked " + settled.size() + " pancakes", width/2, height/2 + 20);
    text("Click to restart", width/2, height/2 + 55);
  }
}
