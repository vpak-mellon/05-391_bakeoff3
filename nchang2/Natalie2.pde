import java.util.Arrays;
import java.util.Collections;
import java.util.Random;

// Set the DPI to make your smartwatch 1 inch square. Measure it on the screen
final int DPIofYourDeviceScreen = 100; // look up your device's DPI/PPI!

String[] phrases;
int totalTrialNum = 3 + (int)random(3);
int currTrialNum = 0;
float startTime = 0;
float finishTime = 0;
float lastTime = 0;
float lettersEnteredTotal = 0;
float lettersExpectedTotal = 0;
float errorsTotal = 0;
String currentPhrase = "";
String currentTyped = "";
final float sizeOfInputArea = DPIofYourDeviceScreen * 1;
PImage watch;
PImage mouseCursor;
float cursorHeight;
float cursorWidth;

// ── U-pad state ───────────────────────────────────────────────────────────────
String vowels     = "aeiou";
String consonants = "bcdfghjklmnpqrstvwxyz";
boolean showVowels = false;

int selectedItem = 10;
int hoveredItem = -1;
boolean onPad = false;

// ── Swipe state ───────────────────────────────────────────────────────────────
float swipeStartX   = 0;
float swipeStartY   = 0;
boolean swipeActive = false;
final float SWIPE_THRESHOLD = 30;

float swipeIndicatorAlpha = 0;
String swipeHint = "";

// U-pad geometry
float uSW;
float uCornerR;
float uLX, uRX;
float uTopY;
float uBotY;
float uBLcx, uBLcy;
float uBRcx, uBRcy;
float uSeg0, uSeg1, uSeg2, uSeg3, uSeg4, uLen;

// Cursor tip offset (tip is near top-left of the finger image)
// The image is drawn at: mouseX + cursorWidth/2 - cursorWidth/3, mouseY + cursorHeight/2 - cursorHeight/5
// So the tip of the finger (top of image) maps back to approximately mouseX, mouseY
// We use raw mouseX/mouseY as the tip — no extra offset needed since tip = mouse position.
// (Kept as explicit variables for easy tuning)
final float TIP_OFFSET_X = 0;
final float TIP_OFFSET_Y = 0;

float tipX() { return mouseX + TIP_OFFSET_X; }
float tipY() { return mouseY + TIP_OFFSET_Y; }

String currentAlphabet() {
  return showVowels ? vowels : consonants;
}

int numItems() {
  return currentAlphabet().length();
}

void setup() {
  watch = loadImage("watchhand3smaller.png");
  phrases = loadStrings("phrases2.txt");
  Collections.shuffle(Arrays.asList(phrases), new Random());
  orientation(LANDSCAPE);
  size(800, 800);
  textFont(createFont("Arial", 24));
  noStroke();
  noCursor();
  mouseCursor = loadImage("finger.png");
  cursorHeight = DPIofYourDeviceScreen * (400.0 / 250.0);
  cursorWidth  = cursorHeight * 0.6;
  computeUGeometry();
}

void computeUGeometry() {
  float cx   = width / 2.0;
  float cy   = height / 2.0;
  float half = sizeOfInputArea / 2.0;
  float iay  = cy - half;

  uSW      = sizeOfInputArea * 0.22;
  uCornerR = uSW * 0.4;
  uLX   = cx - half + uSW * 0.5;
  uRX   = cx + half - uSW * 0.5;
  uTopY = iay;
  uBotY = iay + sizeOfInputArea - uSW * 0.5;
  uBLcx = uLX + uCornerR;  uBLcy = uBotY - uCornerR;
  uBRcx = uRX - uCornerR;  uBRcy = uBotY - uCornerR;
  uSeg0 = uBLcy - uTopY;
  uSeg1 = uCornerR * HALF_PI;
  uSeg2 = uBRcx - uBLcx;
  uSeg3 = uCornerR * HALF_PI;
  uSeg4 = uSeg0;
  uLen  = uSeg0 + uSeg1 + uSeg2 + uSeg3 + uSeg4;
}

float[] uPt(float t) {
  t = constrain(t, 0, uLen);
  float base = 0;
  if (t <= base + uSeg0)
    return new float[]{ uLX, uTopY + (t - base) };
  base += uSeg0;
  if (t <= base + uSeg1) {
    float s = (t - base) / uSeg1;
    float angle = PI - s * HALF_PI;
    return new float[]{ uBLcx + uCornerR * cos(angle), uBLcy + uCornerR * sin(angle) };
  }
  base += uSeg1;
  if (t <= base + uSeg2)
    return new float[]{ uBLcx + (t - base), uBotY };
  base += uSeg2;
  if (t <= base + uSeg3) {
    float s = (t - base) / uSeg3;
    float angle = HALF_PI - s * HALF_PI;
    return new float[]{ uBRcx + uCornerR * cos(angle), uBRcy + uCornerR * sin(angle) };
  }
  base += uSeg3;
  float s = t - base;
  return new float[]{ uRX, uBRcy - s };
}

float[] uNorm(float t) {
  float base = 0;
  if (t <= base + uSeg0) return new float[]{  1,  0 };
  base += uSeg0;
  if (t <= base + uSeg1) {
    float s = (t - base) / uSeg1;
    float angle = PI - s * HALF_PI;
    return new float[]{ -cos(angle), -sin(angle) };
  }
  base += uSeg1;
  if (t <= base + uSeg2) return new float[]{  0, -1 };
  base += uSeg2;
  if (t <= base + uSeg3) {
    float s = (t - base) / uSeg3;
    float angle = HALF_PI - s * HALF_PI;
    return new float[]{ -cos(angle), -sin(angle) };
  }
  base += uSeg3;
  return new float[]{ -1,  0 };
}

float itemT(int i) {
  return uLen * (i + 0.5f) / numItems();
}

String itemLabel(int i) {
  return ("" + currentAlphabet().charAt(i)).toUpperCase();
}

boolean insideUInterior(float mx, float my) {
  float cx   = width / 2.0;
  float cy   = height / 2.0;
  float half = sizeOfInputArea / 2.0;
  float iay  = cy - half;
  return mx > uLX + uSW * 0.5 &&
         mx < uRX - uSW * 0.5 &&
         my > iay &&
         my < uBotY - uSW * 0.5;
}

// ── Draw ──────────────────────────────────────────────────────────────────────
void draw() {
  background(255);
  drawWatch();

  fill(100);
  rect(width/2 - sizeOfInputArea/2, height/2 - sizeOfInputArea/2,
       sizeOfInputArea, sizeOfInputArea);

  if (finishTime != 0) {
    fill(128);
    textAlign(CENTER);
    text("Finished", 280, 150);
    cursor(ARROW);
    return;
  }

  if (startTime == 0 & !mousePressed) {
    fill(128);
    textAlign(CENTER);
    text("Click to start time!", 280, 150);
  }

  if (startTime == 0 & mousePressed) {
    nextTrial();
  }

  if (startTime != 0) {
    textAlign(LEFT);
    fill(128);
    text("Phrase " + (currTrialNum + 1) + " of " + totalTrialNum, 70, 50);
    fill(128);
    text("Target:   " + currentPhrase, 70, 100);
    text("Entered:  " + currentTyped + "|", 70, 140);

    fill(255, 0, 0);
    rect(600, 600, 200, 200);
    fill(255);
    text("NEXT > ", 650, 650);

    drawUPad();
  }

  if (swipeIndicatorAlpha > 0) swipeIndicatorAlpha -= 4;

  image(mouseCursor,
        mouseX + cursorWidth/2 - cursorWidth/3,
        mouseY + cursorHeight/2 - cursorHeight/5,
        cursorWidth, cursorHeight);
}

void drawUPad() {
  float cx   = width / 2.0;
  float cy   = height / 2.0;
  float half = sizeOfInputArea / 2.0;
  float sw   = uSW;
  float iax  = cx - half;
  float iay  = cy - half;

  // Use cursor tip position for hover detection
  float tx = tipX();
  float ty = tipY();

  // 1. DEL and SPACE — LARGER buttons (rowH = sizeOfInputArea / 4.5)
  float btnStartX = uLX + uSW * 0.5;
  float btnEndX   = uRX - uSW * 0.5;
  float btnTotalW = btnEndX - btnStartX;
  float colW      = btnTotalW / 2.0;
  float rowH      = sizeOfInputArea / 4.5;
  float btnY      = iay;

  boolean hoverDel   = tx > btnStartX        && tx < btnStartX + colW && ty > btnY && ty < btnY + rowH;
  boolean hoverSpace = tx > btnStartX + colW && tx < btnEndX          && ty > btnY && ty < btnY + rowH;

  noStroke();
  fill(hoverDel   ? color(60, 200, 90) : color(190, 70, 70));
  rect(btnStartX + 3,        btnY + 3, colW - 6, rowH - 6, 6);
  fill(hoverSpace ? color(60, 200, 90) : color(60, 150, 90));
  rect(btnStartX + colW + 3, btnY + 3, colW - 6, rowH - 6, 6);

  fill(255);
  textSize(11);
  textAlign(CENTER, CENTER);
  text("DEL", btnStartX + colW / 2.0,        btnY + rowH / 2.0);
  text("SPC", btnStartX + colW + colW / 2.0, btnY + rowH / 2.0);

  // 2. U strip rects
  noStroke();
  fill(28, 48, 95);
  rect(iax,                        uTopY, sw, uBLcy - uTopY + uCornerR);
  rect(iax,                        uBotY - sw * 0.5, sizeOfInputArea, sw);
  rect(iax + sizeOfInputArea - sw, uTopY, sw, uBRcy - uTopY + uCornerR);

  // 3. Curved corner fill
  stroke(28, 48, 95);
  strokeWeight(sw);
  strokeCap(SQUARE);
  noFill();
  arc(uBLcx, uBLcy, uCornerR * 2, uCornerR * 2, HALF_PI, PI);
  arc(uBRcx, uBRcy, uCornerR * 2, uCornerR * 2, 0, HALF_PI);
  noStroke();

  // 4. Carve inner corners
  fill(100);
  arc(iax + sw,                   uBotY - sw * 0.5, uCornerR * 2, uCornerR * 2, 3 * HALF_PI, TWO_PI, PIE);
  arc(iax + sizeOfInputArea - sw, uBotY - sw * 0.5, uCornerR * 2, uCornerR * 2, PI, 3 * HALF_PI, PIE);

  // 5. Dots — use tip position for active detection
  noStroke();
  int activeItem = (hoveredItem >= 0) ? hoveredItem : selectedItem;
  for (int i = 0; i < numItems(); i++) {
    float[] pt = uPt(itemT(i));
    boolean active = (i == activeItem);
    fill(active ? color(255, 185, 30) : color(105, 150, 255, 130));
    float r = active ? uSW * 0.20 : uSW * 0.14;
    ellipse(pt[0], pt[1], r * 2, r * 2);
  }

  // 6. Nearby letter labels
  textAlign(CENTER, CENTER);
  for (int i = 0; i < numItems(); i++) {
    if (hoveredItem < 0) break;
    int diff = abs(i - hoveredItem);
    if (diff > numItems() / 2) diff = numItems() - diff;
    if (diff <= 2) {
      float[] pt = uPt(itemT(i));
      float[] n  = uNorm(itemT(i));
      float labelDist = uSW * 0.85;
      float lx = pt[0] + n[0] * labelDist;
      float ly = pt[1] + n[1] * labelDist;
      boolean active = (i == activeItem);
      textSize(active ? 9 : 8);
      fill(active ? color(255, 220, 80) : color(200, 200, 200));
      text(itemLabel(i), lx, ly);
    }
  }

  // 7. Large letter in U interior (while hovering)
  float uInteriorMidY = uTopY + (uBotY - uSW * 0.5 - uTopY) / 2.0;
  if (hoveredItem >= 0) {
    float[] hpt = uPt(itemT(hoveredItem));
    float slotSize = uLen / numItems();
    if (dist(tx, ty, hpt[0], hpt[1]) <= slotSize * 4) {
      noStroke();
      fill(color(255, 220, 80));
      textAlign(CENTER, CENTER);
      textSize(28);
      text(itemLabel(hoveredItem), cx, uInteriorMidY);
    }
  }

  // 8. Mode label only (no swipe instructions)
  float hintY = uInteriorMidY + sizeOfInputArea * 0.20;
  noStroke();
  textAlign(CENTER, CENTER);
  textSize(7);
  fill(showVowels ? color(255, 185, 30, 180) : color(105, 150, 255, 180));
  text(showVowels ? "VOWELS" : "CONSONANTS", cx, hintY - 6);

  // Flash on successful toggle
  if (swipeIndicatorAlpha > 0) {
    noStroke();
    textSize(10);
    fill(255, 220, 80, swipeIndicatorAlpha * 2);
    textAlign(CENTER, CENTER);
    text(swipeHint, cx, hintY + 5);
  }

  textSize(24);
  textAlign(LEFT);
}

// ── Input handling — all use tip position ─────────────────────────────────────
void mousePressed() {
  if (startTime == 0) return;

  float tx = tipX();
  float ty = tipY();

  if (didMouseClick(600, 600, 200, 200)) {
    nextTrial();
    return;
  }

  float cx   = width / 2.0;
  float cy   = height / 2.0;
  float iay  = cy - sizeOfInputArea / 2.0;

  float btnStartX = uLX + uSW * 0.5;
  float btnEndX   = uRX - uSW * 0.5;
  float btnTotalW = btnEndX - btnStartX;
  float colW      = btnTotalW / 2.0;
  float rowH      = sizeOfInputArea / 4.5;
  float btnY      = iay;

  if (ty > btnY && ty < btnY + rowH) {
    if (tx > btnStartX && tx < btnStartX + colW) {
      if (currentTyped.length() > 0)
        currentTyped = currentTyped.substring(0, currentTyped.length() - 1);
      return;
    }
    if (tx > btnStartX + colW && tx < btnEndX) {
      currentTyped += " ";
      return;
    }
  }

  // Begin swipe if in interior
  if (insideUInterior(tx, ty)) {
    swipeStartX = tx;
    swipeStartY = ty;
    swipeActive = true;
    return;
  }

  // U-pad letter selection
  float slotSize = uLen / numItems();
  float closestDist = 1e9;
  int closestIdx = -1;
  for (int i = 0; i < numItems(); i++) {
    float[] pt = uPt(itemT(i));
    float d = dist(tx, ty, pt[0], pt[1]);
    if (d < closestDist) { closestDist = d; closestIdx = i; }
  }
  if (closestDist <= slotSize * 4) {
    onPad = true;
    selectedItem = closestIdx;
  }
}

void mouseMoved() {
  float tx = tipX();
  float ty = tipY();

  hoveredItem = -1;
  float slotSize = uLen / numItems();
  float closestDist = 1e9;
  int closestIdx = -1;
  for (int i = 0; i < numItems(); i++) {
    float[] pt = uPt(itemT(i));
    float d = dist(tx, ty, pt[0], pt[1]);
    if (d < closestDist) { closestDist = d; closestIdx = i; }
  }
  if (closestDist <= slotSize * 4) {
    hoveredItem = closestIdx;
  }
}

void mouseDragged() {
  if (swipeActive) return;

  float tx = tipX();
  float ty = tipY();

  float slotSize = uLen / numItems();
  float closestDist = 1e9;
  int closestIdx = -1;
  for (int i = 0; i < numItems(); i++) {
    float[] pt = uPt(itemT(i));
    float d = dist(tx, ty, pt[0], pt[1]);
    if (d < closestDist) { closestDist = d; closestIdx = i; }
  }
  if (closestDist <= slotSize * 4) {
    selectedItem = closestIdx;
    hoveredItem = closestIdx;
  }
}

void mouseReleased() {
  float tx = tipX();
  float ty = tipY();

  // Evaluate swipe
  if (swipeActive) {
    swipeActive = false;
    float dx = tx - swipeStartX;
    float dy = ty - swipeStartY;
    if (abs(dx) >= SWIPE_THRESHOLD && abs(dx) > abs(dy) * 1.2) {
      showVowels = !showVowels;
      selectedItem = 0;
      hoveredItem = -1;
      swipeIndicatorAlpha = 120;
      swipeHint = showVowels ? "◀ VOWELS" : "CONSONANTS ▶";
    }
    return;
  }

  if (!onPad) return;
  onPad = false;
  hoveredItem = -1;
  currentTyped += currentAlphabet().charAt(selectedItem);
}

boolean didMouseClick(float x, float y, float w, float h) {
  return (mouseX > x && mouseX < x+w && mouseY > y && mouseY < y+h);
}

// ── Trial management ──────────────────────────────────────────────────────────
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
  onPad         = false;
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
