import java.util.Arrays;
import java.util.Collections;
import java.util.Random;

// Set the DPI to make your smartwatch 1 inch square.
final int DPIofYourDeviceScreen = 250;

// Do not change the following variables
String[] phrases;
String[] suggestions;
int totalTrialNum = 2;
int currTrialNum = 0;
float startTime = 0, finishTime = 0, lastTime = 0;
float lettersEnteredTotal = 0, lettersExpectedTotal = 0, errorsTotal = 0;
String currentPhrase = "", currentTyped = "";
final float sizeOfInputArea = DPIofYourDeviceScreen * 1;
PImage watch, mouseCursor;
float cursorHeight, cursorWidth;

// ── U-pad design ──────────────────────────────────────────────────────────────
//  A thick strip runs along three edges of the watch face:
//    left arm  (top-left corner  → bottom-left, curved into bottom)
//    bottom    (curved left corner → curved right corner)
//    right arm (bottom-right, curved → top-right corner)
//
//  28 items: index 0 = DEL, 1-26 = a-z, 27 = space
//  Press/drag on strip → select; release → commit.

final int NUM_ITEMS = 28;
String alphabet = "abcdefghijklmnopqrstuvwxyz";
int selectedItem = 13;
boolean onPad = false;
float totalPadDrag = 0;

// U geometry — all set in setup()
float uSW;        // strip width
float uCornerR;   // inner-corner curve radius
float uLX, uRX;   // arm centerline X positions
float uTopY;      // top of arms  (= watch face top edge)
float uBotY;      // bottom-strip centerline Y
// Bottom corner arc centers
float uBLcx, uBLcy; // bottom-left arc center
float uBRcx, uBRcy; // bottom-right arc center
// Segment arc-lengths
float uSeg0; // left arm straight
float uSeg1; // bottom-left corner arc
float uSeg2; // bottom straight
float uSeg3; // bottom-right corner arc
float uSeg4; // right arm straight
float uLen;  // total

PFont fontHuge, fontLarge, fontMed, fontSmall, fontScaffold;

// ── Setup ─────────────────────────────────────────────────────────────────────
void setup() {
  watch = loadImage("watchhand3smaller.png");
  phrases = loadStrings("phrases2.txt");
  Collections.shuffle(Arrays.asList(phrases), new Random());
  orientation(LANDSCAPE);
  size(800, 800);

  fontScaffold = createFont("Arial", 24);
  fontHuge     = createFont("Arial Bold", 90);
  fontLarge    = createFont("Arial", 26);
  fontMed      = createFont("Arial", 17);
  fontSmall    = createFont("Arial", 11);
  textFont(fontScaffold);

  noStroke(); noCursor();
  mouseCursor  = loadImage("finger.png");
  cursorHeight = DPIofYourDeviceScreen * (400.0 / 250.0);
  cursorWidth  = cursorHeight * 0.6;

  float cx = width / 2.0, cy = height / 2.0, half = sizeOfInputArea / 2.0;

  uSW      = sizeOfInputArea * 0.16;   // ~40 px
  uCornerR = uSW * 1.4;               // ~40 px — controls inner corner curve

  uLX   = cx - half + uSW * 0.5;
  uRX   = cx + half - uSW * 0.5;
  uTopY = cy - half;                   // arms reach the very top corners
  uBotY = cy + half - uSW * 0.5;

  // Arc centers for the two curved bottom corners
  uBLcx = uLX + uCornerR;  uBLcy = uBotY - uCornerR;
  uBRcx = uRX - uCornerR;  uBRcy = uBotY - uCornerR;

  uSeg0 = uBLcy - uTopY;            // left arm straight (top → arc start)
  uSeg1 = uCornerR * HALF_PI;       // bottom-left corner arc
  uSeg2 = uBRcx - uBLcx;           // bottom straight
  uSeg3 = uCornerR * HALF_PI;       // bottom-right corner arc
  uSeg4 = uSeg0;                    // right arm straight (symmetric)
  uLen  = uSeg0 + uSeg1 + uSeg2 + uSeg3 + uSeg4;
}

// ── U path: arc-length t → (x, y) on centerline ───────────────────────────────
// Path direction: down left arm → curve → right along bottom → curve → up right arm
float[] uPt(float t) {
  t = constrain(t, 0, uLen);
  float base = 0;

  // Seg 0 — left arm, straight down
  if (t <= base + uSeg0) {
    return new float[]{ uLX, uTopY + (t - base) };
  }
  base += uSeg0;

  // Seg 1 — bottom-left corner arc
  // Arc center: (uBLcx, uBLcy). Angle goes from π (point = left of center) to π/2 (point = below center).
  // In screen coords (y-down): angle π → left, angle π/2 → DOWN. Arc goes from "left arm exit" down to "bottom entry".
  // Wait, I need to recalculate correctly.
  // At start of arc (s=0): point = (uLX, uBLcy) → relative to center = (-uCornerR, 0) → angle = π ✓
  // At end of arc (s=1): point = (uBLcx, uBotY) → relative to center = (0, +uCornerR) → angle = π/2 (in Processing y-down: π/2 = downward) ✓
  // So angle decreases from π to π/2.
  if (t <= base + uSeg1) {
    float s = (t - base) / uSeg1;
    float angle = PI - s * HALF_PI;   // π → π/2
    return new float[]{ uBLcx + uCornerR * cos(angle), uBLcy + uCornerR * sin(angle) };
  }
  base += uSeg1;

  // Seg 2 — bottom, straight right
  if (t <= base + uSeg2) {
    return new float[]{ uBLcx + (t - base), uBotY };
  }
  base += uSeg2;

  // Seg 3 — bottom-right corner arc
  // Arc center: (uBRcx, uBRcy).
  // At start (s=0): (uBRcx, uBotY) → relative = (0, +uCornerR) → angle = π/2 ✓
  // At end (s=1): (uRX, uBRcy) → relative = (+uCornerR, 0) → angle = 0 ✓
  // Angle decreases from π/2 to 0.
  if (t <= base + uSeg3) {
    float s = (t - base) / uSeg3;
    float angle = HALF_PI - s * HALF_PI;   // π/2 → 0
    return new float[]{ uBRcx + uCornerR * cos(angle), uBRcy + uCornerR * sin(angle) };
  }
  base += uSeg3;

  // Seg 4 — right arm, straight up
  float s = t - base;
  return new float[]{ uRX, uBRcy - s };
}

// Inward-facing unit normal at arc-length t
float[] uNorm(float t) {
  float base = 0;
  if (t <= base + uSeg0) return new float[]{  1,  0 }; // left arm → right
  base += uSeg0;
  if (t <= base + uSeg1) {
    float s = (t - base) / uSeg1;
    float angle = PI - s * HALF_PI;
    return new float[]{ -cos(angle), -sin(angle) }; // toward arc center
  }
  base += uSeg1;
  if (t <= base + uSeg2) return new float[]{  0, -1 }; // bottom → up
  base += uSeg2;
  if (t <= base + uSeg3) {
    float s = (t - base) / uSeg3;
    float angle = HALF_PI - s * HALF_PI;
    return new float[]{ -cos(angle), -sin(angle) };
  }
  base += uSeg3;
  return new float[]{ -1,  0 }; // right arm → left
}

// Arc-length t for item i (centered in its slot)
float itemT(int i) {
  return uLen * (i + 0.5f) / NUM_ITEMS;
}

// Closest arc-length t to mouse position (mx, my)
float closestT(float mx, float my) {
  float bestT = 0, bestD = 1e9;
  float base = 0;

  // Seg 0 — left arm
  float cy0 = constrain(my, uTopY, uTopY + uSeg0);
  float d0  = dist(mx, my, uLX, cy0);
  if (d0 < bestD) { bestD = d0; bestT = base + (cy0 - uTopY); }
  base += uSeg0;

  // Seg 1 — bottom-left arc (angle range [π/2, π])
  float a1 = atan2(my - uBLcy, mx - uBLcx);
  a1 = constrain(a1, HALF_PI, PI);
  float s1 = (PI - a1) / HALF_PI;  // maps [π→0, π/2→1]
  float[] p1 = new float[]{ uBLcx + uCornerR * cos(a1), uBLcy + uCornerR * sin(a1) };
  float d1 = dist(mx, my, p1[0], p1[1]);
  if (d1 < bestD) { bestD = d1; bestT = base + s1 * uSeg1; }
  base += uSeg1;

  // Seg 2 — bottom straight
  float cx2 = constrain(mx, uBLcx, uBRcx);
  float d2  = dist(mx, my, cx2, uBotY);
  if (d2 < bestD) { bestD = d2; bestT = base + (cx2 - uBLcx); }
  base += uSeg2;

  // Seg 3 — bottom-right arc (angle range [0, π/2])
  float a3 = atan2(my - uBRcy, mx - uBRcx);
  a3 = constrain(a3, 0, HALF_PI);
  float s3 = 1.0 - a3 / HALF_PI;  // maps [π/2→0, 0→1]
  float[] p3 = new float[]{ uBRcx + uCornerR * cos(a3), uBRcy + uCornerR * sin(a3) };
  float d3 = dist(mx, my, p3[0], p3[1]);
  if (d3 < bestD) { bestD = d3; bestT = base + s3 * uSeg3; }
  base += uSeg3;

  // Seg 4 — right arm
  float cy4 = constrain(my, uTopY, uBRcy);
  float d4  = dist(mx, my, uRX, cy4);
  if (d4 < bestD) { bestD = d4; bestT = base + (uBRcy - cy4); }

  return bestT;
}

boolean nearU(float mx, float my) {
  float[] pt = uPt(closestT(mx, my));
  return dist(mx, my, pt[0], pt[1]) <= uSW * 1.2;
}

String itemLabel(int i) {
  if (i == 0)  return "DEL";
  if (i == 27) return "SPC";
  return ("" + alphabet.charAt(i - 1)).toUpperCase();
}

// ── Draw ──────────────────────────────────────────────────────────────────────
void draw() {
  background(225);
  drawWatch();

  fill(15, 18, 28);
  rect(width/2 - sizeOfInputArea/2, height/2 - sizeOfInputArea/2,
       sizeOfInputArea, sizeOfInputArea);

  if (finishTime != 0) {
    fill(60); textFont(fontLarge); textAlign(CENTER);
    text("Finished!", width/2, 220);
    cursor(ARROW); return;
  }

  if (startTime == 0 && !mousePressed) {
    fill(70); textFont(fontMed); textAlign(CENTER);
    text("Tap anywhere to begin", width/2, 220);
  }
  if (startTime == 0 && mousePressed) nextTrial();

  if (startTime != 0) {
    drawTextArea();
    drawUPad();
    drawNextButton();
  }

  image(mouseCursor,
        mouseX + cursorWidth/2 - cursorWidth/3,
        mouseY + cursorHeight/2 - cursorHeight/5,
        cursorWidth, cursorHeight);
}

// ── Text area (matches original scaffold format) ──────────────────────────────
void drawTextArea() {
  textFont(fontScaffold);
  textAlign(LEFT);
  fill(128);
  text("Phrase " + (currTrialNum+1) + " of " + totalTrialNum, 70, 50);
  fill(128);
  text("Target:   " + currentPhrase, 70, 100);
  text("Entered:  " + currentTyped + "|", 70, 140);
}

// ── U pad ─────────────────────────────────────────────────────────────────────
void drawUPad() {
  float cx   = width / 2.0;
  float cy   = height / 2.0;
  float half = sizeOfInputArea / 2.0;
  float sw   = uSW;

  // ── 1. Draw three solid rects for left arm, bottom strip, right arm ──
  //    They intentionally overlap at the corner regions.
  fill(28, 48, 95);

  // Left arm: full height from top corner to where arc takes over
  rect(cx - half, uTopY, sw, uBLcy - uTopY + uCornerR);
  // Bottom strip: full width
  rect(cx - half, uBotY - sw * 0.5, sizeOfInputArea, sw);
  // Right arm: full height
  rect(cx + half - sw, uTopY, sw, uBRcy - uTopY + uCornerR);

  // ── 2. Fill the corner arc-band areas (same strip color) ──
  //    Draw thick arcs to fill the rounded corner strips
  noFill();
  stroke(28, 48, 95);
  strokeWeight(sw);
  strokeCap(SQUARE);
  // Bottom-left corner arc (from angle π to π/2, decreasing)
  arc(uBLcx, uBLcy, uCornerR * 2, uCornerR * 2, HALF_PI, PI);
  // Bottom-right corner arc (from angle 0 to π/2)
  arc(uBRcx, uBRcy, uCornerR * 2, uCornerR * 2, 0, HALF_PI);
  noStroke();

  // ── 3. Carve inner corners with background color (concave curve) ──
  //    Draws a filled quarter-disc in watch-background color to round the inner corner.
  fill(15, 18, 28);
  // Bottom-left inner corner: carve upper-right quadrant (from up → right visually)
  arc(cx - half + sw, uBotY - sw * 0.5, uCornerR * 2, uCornerR * 2,
      3 * HALF_PI, TWO_PI, PIE);
  // Bottom-right inner corner: carve upper-left quadrant (from left → up visually)
  arc(cx + half - sw, uBotY - sw * 0.5, uCornerR * 2, uCornerR * 2,
      PI, 3 * HALF_PI, PIE);

  // ── 4. Dots along the path ──
  for (int i = 0; i < NUM_ITEMS; i++) {
    float[] pt = uPt(itemT(i));
    boolean sel = (i == selectedItem);
    fill(sel ? color(255, 185, 30) : color(105, 150, 255, 130));
    float r = sel ? 7 : 2.5;
    ellipse(pt[0], pt[1], r * 2, r * 2);
  }

  // ── 5. Neighbour labels along the strip ──
  for (int i = max(0, selectedItem - 4); i <= min(NUM_ITEMS - 1, selectedItem + 4); i++) {
    if (i == selectedItem) continue;
    float t     = itemT(i);
    float[] pt  = uPt(t);
    float[] nm  = uNorm(t);
    float   d   = abs(i - selectedItem);
    float   alp = lerp(210, 15, d / 5.0);

    fill(200, alp);
    textFont(fontSmall);
    textAlign(CENTER);
    text(itemLabel(i), pt[0] + nm[0] * sw * 0.85, pt[1] + nm[1] * sw * 0.85 + 4);
  }

  // ── 6. Glowing finger-position ring while touching ──
  if (onPad) {
    float[] pt = uPt(closestT(mouseX, mouseY));
    noFill();
    stroke(255, 185, 30, 180);
    strokeWeight(3);
    ellipse(pt[0], pt[1], sw * 1.7, sw * 1.7);
    noStroke();
  }

  // ── 7. Selected letter — large, centred in the display zone ──
  boolean special = (selectedItem == 0 || selectedItem == 27);
  float dispTop = cy - half;
  float dispBot = uBotY - sw * 0.5;
  float dispMid = (dispTop + dispBot) / 2.0;

  // Find current word in phrase and show it with per-character colouring
  // Current word = the word at index currentTyped.length() in the phrase
  int typedLen = currentTyped.length();
  // Find word start: last space before typedLen in currentPhrase
  int wordStart = 0;
  for (int i = 0; i < typedLen && i < currentPhrase.length(); i++) {
    if (currentPhrase.charAt(i) == ' ') wordStart = i + 1;
  }
  // Find word end: next space after wordStart
  int wordEnd = currentPhrase.length();
  for (int i = wordStart; i < currentPhrase.length(); i++) {
    if (currentPhrase.charAt(i) == ' ') { wordEnd = i; break; }
  }
  String currentWord = currentPhrase.substring(wordStart, wordEnd);

  textFont(fontMed);
  textAlign(CENTER);
  float wordY = dispMid - 18;
  // Draw char by char centered
  float totalW = textWidth(currentWord);
  float charX  = cx - totalW / 2.0;
  for (int i = 0; i < currentWord.length(); i++) {
    char exp      = currentWord.charAt(i);
    int  absIdx   = wordStart + i;
    float cw      = textWidth("" + exp);
    if (absIdx < typedLen)
      fill(currentTyped.charAt(absIdx) == exp ? color(80, 210, 90) : color(220, 60, 60));
    else
      fill(180);
    text("" + exp, charX + cw / 2.0, wordY);
    charX += cw;
  }

  // Big selected letter below the word
  fill(255, 185, 30);
  textFont(special ? fontLarge : fontHuge);
  textAlign(CENTER);
  text(itemLabel(selectedItem), cx, dispMid + (special ? 30 : 50));

  // Reset font so drawNextButton and drawTextArea aren't affected
  textFont(fontScaffold);
}

// ── NEXT button (matches original scaffold position) ──────────────────────────
void drawNextButton() {
  fill(255, 0, 0);
  rect(600, 600, 200, 200);
  fill(255);
  textFont(fontScaffold);
  textAlign(LEFT);
  text("NEXT > ", 650, 650);
}

// ── Input ─────────────────────────────────────────────────────────────────────
void mousePressed() {
  if (startTime == 0) return;
  if (mouseX >= 600 && mouseX <= 800 && mouseY >= 600 && mouseY <= 800) {
    nextTrial(); return;
  }
  if (nearU(mouseX, mouseY)) {
    onPad = true;
    totalPadDrag = 0;
    selectedItem = constrain((int)(closestT(mouseX, mouseY) / uLen * NUM_ITEMS), 0, NUM_ITEMS - 1);
  }
}

void mouseDragged() {
  if (!onPad) return;
  totalPadDrag += dist(mouseX, mouseY, pmouseX, pmouseY);
  selectedItem = constrain((int)(closestT(mouseX, mouseY) / uLen * NUM_ITEMS), 0, NUM_ITEMS - 1);
}

void mouseReleased() {
  if (!onPad) return;
  onPad = false;
  if (selectedItem == 0) {
    if (currentTyped.length() > 0)
      currentTyped = currentTyped.substring(0, currentTyped.length() - 1);
  } else if (selectedItem == 27) {
    currentTyped += " ";
  } else {
    currentTyped += alphabet.charAt(selectedItem - 1);
  }
}

// ── Trial management (do not modify) ─────────────────────────────────────────
void nextTrial() {
  if (currTrialNum >= totalTrialNum) return;

  if (startTime != 0 && finishTime == 0) {
    System.out.println("==================");
    System.out.println("Phrase " + (currTrialNum + 1) + " of " + totalTrialNum);
    System.out.println("Target phrase: " + currentPhrase);
    System.out.println("Phrase length: " + currentPhrase.length());
    System.out.println("User typed: " + currentTyped);
    System.out.println("User typed length: " + currentTyped.length());
    System.out.println("Number of errors: " + computeLevenshteinDistance(currentTyped.trim(), currentPhrase.trim()));
    System.out.println("Time taken on this trial: " + (millis() - lastTime));
    System.out.println("Time taken since beginning: " + (millis() - startTime));
    System.out.println("==================");
    lettersExpectedTotal += currentPhrase.trim().length();
    lettersEnteredTotal  += currentTyped.trim().length();
    errorsTotal          += computeLevenshteinDistance(currentTyped.trim(), currentPhrase.trim());
  }

  if (currTrialNum == totalTrialNum - 1) {
    finishTime = millis();
    System.out.println("==================");
    System.out.println("Trials complete!");
    System.out.println("Total time taken: " + (finishTime - startTime));
    System.out.println("Total letters entered: " + lettersEnteredTotal);
    System.out.println("Total letters expected: " + lettersExpectedTotal);
    System.out.println("Total errors entered: " + errorsTotal);

    float wpm           = (lettersEnteredTotal / 5.0f) / ((finishTime - startTime) / 60000f);
    float freebieErrors = lettersExpectedTotal * .05;
    float penalty       = max(errorsTotal - freebieErrors, 0) * .5f;

    System.out.println("Raw WPM: " + wpm);
    System.out.println("Freebie errors: " + freebieErrors);
    System.out.println("Penalty: " + penalty);
    System.out.println("WPM w/ penalty: " + (wpm - penalty));
    System.out.println("==================");

    currTrialNum++;
    return;
  }

  if (startTime == 0) {
    System.out.println("Trials beginning! Starting timer...");
    startTime = millis();
  } else {
    currTrialNum++;
  }

  lastTime      = millis();
  currentTyped  = "";
  currentPhrase = phrases[currTrialNum];
}

void drawWatch() {
  float watchscale = DPIofYourDeviceScreen / 138.0;
  pushMatrix();
  translate(width / 2, height / 2);
  scale(watchscale);
  imageMode(CENTER);
  image(watch, 0, 0);
  popMatrix();
}

// ── Levenshtein (do not touch) ────────────────────────────────────────────────
int computeLevenshteinDistance(String phrase1, String phrase2) {
  int[][] distance = new int[phrase1.length() + 1][phrase2.length() + 1];
  for (int i = 0; i <= phrase1.length(); i++) distance[i][0] = i;
  for (int j = 1; j <= phrase2.length(); j++) distance[0][j] = j;
  for (int i = 1; i <= phrase1.length(); i++)
    for (int j = 1; j <= phrase2.length(); j++)
      distance[i][j] = min(min(distance[i-1][j] + 1, distance[i][j-1] + 1),
                           distance[i-1][j-1] + ((phrase1.charAt(i-1) == phrase2.charAt(j-1)) ? 0 : 1));
  return distance[phrase1.length()][phrase2.length()];
}
