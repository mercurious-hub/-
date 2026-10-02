// 팬케이크 쌓기 게임 v1 - Processing
// 마우스를 꾹 눌러 힘을 모으고, 놓으면 팬케이크가 날아갑니다!

final int READY = 0, CHARGING = 1, FLYING = 2, FALLING = 3, GAMEOVER = 4;
int state = READY;

float gravity = 0.5;
float PW = 90;   // 팬케이크 너비
float PH = 16;   // 팬케이크 두께

// 프라이팬 (화면에 고정)
float panX = 120, panY = 600;

// 접시 (월드 좌표)
float plateX = 400, plateY = 650, plateW = 130;

// 날아가는 팬케이크
float px, py, vx, vy, flip, flipSpeed;

// 힘 게이지
float power, minPower = 5, maxPower = 20, powerDir = 1;
float launchAngle = radians(60);

ArrayList<Float> stack = new ArrayList<Float>();  // 쌓인 팬케이크들의 x 위치
int best = 0;
float camY = 0;  // 탑이 높아지면 화면이 따라 올라감

void setup() {
  size(500, 700);
  textAlign(CENTER, CENTER);
  resetGame();
}

void resetGame() {
  stack.clear();
  camY = 0;
  power = minPower;
  powerDir = 1;
  state = READY;
}

void draw() {
  background(255, 244, 225);
  updateGame();

  // 카메라: 탑 꼭대기가 화면 위쪽에 가까워지면 부드럽게 따라감
  float topY = plateY - stack.size() * PH;
  camY = lerp(camY, max(0, 330 - topY), 0.08);

  // ---- 월드 (카메라 영향 받음) ----
  pushMatrix();
  translate(0, camY);
  drawTable();
  drawPlate();
  for (int i = 0; i < stack.size(); i++) {
    drawPancake(stack.get(i), plateY - PH/2 - i * PH, 0);
  }
  if (state == FLYING || state == FALLING) drawPancake(px, py, flip);
  popMatrix();

  // ---- 화면 고정 요소 ----
  drawPan();
  if (state == READY || state == CHARGING) drawPancake(panX, panY - 14, 0);
  if (state == CHARGING) drawGauge();
  drawUI();
}

void updateGame() {
  if (state == CHARGING) {
    // 게이지가 최소↔최대 사이를 왕복
    power += powerDir * 0.3;
    if (power > maxPower) { power = maxPower; powerDir = -1; }
    if (power < minPower) { power = minPower; powerDir = 1; }
  }
  else if (state == FLYING) {
    float prevBottom = py + PH/2;
    vy += gravity;
    px += vx;
    py += vy;
    flip += flipSpeed;
    float bottom = py + PH/2;

    // 떨어지는 중일 때만 착지 체크
    if (vy > 0) {
      float surfaceY = plateY - stack.size() * PH;
      float supportX = stack.isEmpty() ? plateX : stack.get(stack.size() - 1);
      float supportW = stack.isEmpty() ? plateW : PW;

      if (prevBottom <= surfaceY && bottom >= surfaceY) {
        float dx = abs(px - supportX);
        if (dx < supportW / 2) {
          // 착지 성공! (중심이 아래 팬케이크/접시 위에 있음)
          stack.add(px);
          best = max(best, stack.size());
          power = minPower;
          powerDir = 1;
          state = READY;
        } else if (dx < (supportW + PW) / 2) {
          // 가장자리에 걸려서 미끄러져 떨어짐
          state = FALLING;
          vx = (px > supportX) ? 3 : -3;
          flipSpeed = (px > supportX) ? 0.2 : -0.2;
        }
      }
    }
    if (py + camY > height + 60) state = GAMEOVER;
  }
  else if (state == FALLING) {
    vy += gravity;
    px += vx;
    py += vy;
    flip += flipSpeed;
    if (py + camY > height + 60) state = GAMEOVER;
  }
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
    px = panX;
    py = panY - 14 - camY;  // 화면 좌표 → 월드 좌표
    vx = power * cos(launchAngle);
    vy = -power * sin(launchAngle);
    flip = 0;
    flipSpeed = 0.25;
    state = FLYING;
  }
}

// ================= 그리기 =================

void drawPancake(float x, float y, float f) {
  pushMatrix();
  translate(x, y);
  // 세로로 납작해졌다 펴지며 뒤집히는 효과
  float s = cos(f);
  if (abs(s) < 0.15) s = (s < 0) ? -0.15 : 0.15;
  scale(1, s);
  noStroke();
  fill(185, 115, 45);
  ellipse(0, 3, PW, PH);            // 옆면
  fill(235, 175, 90);
  ellipse(0, -2, PW, PH - 2);       // 윗면
  fill(255, 225, 150, 160);
  ellipse(-14, -4, PW * 0.4, PH * 0.35);  // 하이라이트
  popMatrix();
}

void drawTable() {
  noStroke();
  fill(205, 160, 115);
  rect(-10, plateY + 14, width + 20, 600);
}

void drawPlate() {
  noStroke();
  fill(190);
  ellipse(plateX, plateY + 7, plateW + 20, 22);
  fill(250);
  ellipse(plateX, plateY + 2, plateW, 16);
}

void drawPan() {
  noStroke();
  fill(45);
  rect(panX - 120, panY - 4, 70, 10, 4);  // 손잡이
  ellipse(panX, panY, 110, 26);           // 팬 몸체
  fill(75);
  ellipse(panX, panY - 3, 96, 18);        // 팬 안쪽
}

void drawGauge() {
  float t = (power - minPower) / (maxPower - minPower);
  float gx = panX - 50, gy = panY - 70, gw = 100, gh = 12;
  noStroke();
  fill(0, 40);
  rect(gx, gy, gw, gh, 6);
  fill(lerpColor(color(90, 200, 90), color(230, 60, 50), t));
  rect(gx, gy, gw * t, gh, 6);
}

void drawUI() {
  fill(90, 50, 20);
  textSize(56);
  text(stack.size(), width/2, 60);
  textSize(16);
  text("BEST " + best, width/2, 105);

  if (state == READY && stack.isEmpty()) {
    textSize(16);
    text("Hold to charge, release to flip!", width/2, 160);
  }
  if (state == GAMEOVER) {
    fill(0, 120);
    rect(0, 0, width, height);
    fill(255);
    textSize(48);
    text("GAME OVER", width/2, height/2 - 30);
    textSize(20);
    text("Stacked " + stack.size() + " pancakes", width/2, height/2 + 20);
    text("Click to restart", width/2, height/2 + 55);
  }
}
