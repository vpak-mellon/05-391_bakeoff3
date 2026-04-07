import java.util.Arrays;
import java.util.Collections;
import java.util.Random;

// Set the DPI to make your smartwatch 1 inch square.
final int DPIofYourDeviceScreen = 250;

// Do not change the following variables
String[] phrases;
String[] suggestions;
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

// ── Rotary Dial design ───────────────────────────────────────────────────────
//
//  The disc is a spinning ring with 6 letter slots spaced 60° apart.
//  All 26 letters wrap around continuously — spinning clockwise advances
//  through the alphabet. Going from A to Z takes ~4.3 full rotations.
//
//  Gestures:
//    Drag on ring  → rotate disc, current top letter shown large in centre
//    Tap ring      → type the current top letter
//    Tap centre    → space
//    Hold centre   → backspace (red ring fills up in 500 ms)

String alphabet   = "abcdefghijklmnopqrstuvwxyz";
int    numLetters = 26;
int    numSlots   = 6;                        // letters visible around ring
float  slotAngle  = TWO_PI / numSlots;        // 60° per slot

float dialAngle       = 0;   // accumulated rotation (unbounded float)
float targetDialAngle = 0;   // snapped-to-nearest-letter target
float prevMouseAngle  = 0;   // previous frame's mouse angle for delta
boolean dragging      = false;
float   totalDragAngle = 0;  // total absolute rotation this gesture
float   pressStartDist = 0;  // centre-distance where press began

// Hold-for-backspace
float   holdStartTime = 0;
boolean holdActive    = false;
boolean backspaceUsed = false;
final float HOLD_MS   = 500;

// Snap animation
boolean snapping = false;

// Geometry (set in setup)
float discRadius;
float centerRadius;

PFont fontHuge, fontLarge, fontMed, fontSmall;

// ── Setup ─────────────────────────────────────────────────────────────────────
void setup() {
  watch = loadImage("watchhand3smaller.png");
  phrases = loadStrings("phrases2.txt");
  Collections.shuffle(Arrays.asList(phrases), new Random());

  orientation(LANDSCAPE);
  size(800, 800);

  fontHuge  = createFont("Arial", 52);
  fontLarge = createFont("Arial", 28);
  fontMed   = createFont("Arial", 20);
  fontSmall = createFont("Arial", 13);

  noStroke();
  noCursor();
  mouseCursor  = loadImage("finger.png");
  cursorHeight = DPIofYourDeviceScreen * (400.0 / 250.0);
  cursorWidth  = cursorHeight * 0.6;

  discRadius   = sizeOfInputArea * 0.44;  // ~110 px
  centerRadius = sizeOfInputArea * 0.165; // ~41 px
}

// ── Draw ──────────────────────────────────────────────────────────────────────
void draw() {
  background(225);
  drawWatch();

  // Dark watch face (the 1″ input area)
  fill(15, 18, 28);
  rect(width/2 - sizeOfInputArea/2, height/2 - sizeOfInputArea/2,
       sizeOfInputArea, sizeOfInputArea);

  // Animate snap-to-letter when not dragging
  if (!dragging && snapping) {
    dialAngle += (targetDialAngle - dialAngle) * 0.22;
    if (abs(targetDialAngle - dialAngle) < 0.001) {
      dialAngle = targetDialAngle;
      snapping  = false;
    }
  }

  // Hold-for-backspace: fire once ring is full
  if (holdActive && !backspaceUsed && millis() - holdStartTime >= HOLD_MS) {
    if (currentTyped.length() > 0)
      currentTyped = currentTyped.substring(0, currentTyped.length() - 1);
    backspaceUsed = true;
  }

  // ── Finished ──
  if (finishTime != 0) {
    fill(60);
    textFont(fontLarge);
    textAlign(CENTER);
    text("Finished!", width/2, 220);
    cursor(ARROW);
    return;
  }

  // ── Pre-start ──
  if (startTime == 0 && !mousePressed) {
    fill(70);
    textFont(fontMed);
    textAlign(CENTER);
    text("Tap anywhere to begin", width/2, 220);
  }
  if (startTime == 0 && mousePressed) {
    nextTrial();
  }

  // ── Active trials ──
  if (startTime != 0) {
    drawTextArea();
    drawDial();
    drawNextButton();
    drawHints();
  }

  image(mouseCursor,
        mouseX + cursorWidth/2 - cursorWidth/3,
        mouseY + cursorHeight/2 - cursorHeight/5,
        cursorWidth, cursorHeight);
}

// ── Text display (outside watch) ──────────────────────────────────────────────
void drawTextArea() {
  float topY = height/2 - sizeOfInputArea/2;
  float lx   = 20;

  textFont(fontSmall);
  textAlign(LEFT);
  fill(110);
  text("Phrase " + (currTrialNum + 1) + " of " + totalTrialNum, lx, topY - 78);

  // Target phrase with per-character colour feedback
  fill(80);
  textFont(fontMed);
  text("Target:", lx, topY - 50);
  float tx = lx + 90;
  for (int i = 0; i < currentPhrase.length(); i++) {
    char exp = currentPhrase.charAt(i);
    if (i < currentTyped.length())
      fill(currentTyped.charAt(i) == exp ? color(30, 160, 60) : color(200, 40, 40));
    else
      fill(80);
    text("" + exp, tx, topY - 50);
    tx += textWidth("" + exp);
  }

  fill(30);
  textFont(fontMed);
  text("Typed:  " + currentTyped + "|", lx, topY - 18);
}

// ── Rotary dial (inside watch) ────────────────────────────────────────────────
//
//  Letter layout at any moment (6 o'clock = bottom, 12 o'clock = top):
//
//          [top  → current letter, amber]
//       [upper-L]            [upper-R]
//     [lower-L]                 [lower-R]
//              [bottom]
//
//  Rotating clockwise advances the alphabet (A→B→…→Z).
//  With 6 slots at 60° each, all 26 letters span ≈4.3 full rotations.

int topLetterIndex() {
  // Clockwise drag = increasing dialAngle = advancing alphabet
  int idx = ((int) round(dialAngle / slotAngle)) % numLetters;
  if (idx < 0) idx += numLetters;
  return idx;
}

void drawDial() {
  float cx    = width / 2.0;
  float cy    = height / 2.0;
  int   topIdx = topLetterIndex();

  // ── Ring segments (6 slots, evenly distributed 360°) ──
  int half = numSlots / 2; // 3
  for (int k = -half; k < half; k++) {
    float screenAngle = -HALF_PI + k * slotAngle;
    float segStart    = screenAngle - slotAngle / 2;
    float segEnd      = screenAngle + slotAngle / 2;

    // Letter that maps to this slot
    int letterIdx = ((topIdx + k) % numLetters + numLetters) % numLetters;
    boolean isTop = (k == 0);

    // Fade letters away from top
    float alpha = map(abs(k), 0, half, 255, 55);

    // Segment fill
    if (isTop) fill(255, 185, 30);
    else       fill(38, 62, 128, alpha);

    arc(cx, cy, discRadius * 2, discRadius * 2, segStart, segEnd, PIE);

    // Divider
    stroke(15, 18, 28);
    strokeWeight(1.5);
    line(cx, cy,
         cx + cos(segStart) * discRadius,
         cy + sin(segStart) * discRadius);
    noStroke();

    // Letter label on ring
    float labelR = (discRadius + centerRadius) * 0.57;
    float lx = cx + cos(screenAngle) * labelR;
    float ly = cy + sin(screenAngle) * labelR;

    textFont(fontSmall);
    textAlign(CENTER);
    fill(isTop ? color(20) : color(220, alpha));
    text(("" + alphabet.charAt(letterIdx)).toUpperCase(), lx, ly + 5);
  }

  // ── Centre hole ──
  fill(15, 18, 28);
  ellipse(cx, cy, centerRadius * 2, centerRadius * 2);

  // Hold-for-backspace progress arc (drawn around edge of centre hole)
  if (holdActive && !backspaceUsed) {
    float t = constrain((millis() - holdStartTime) / HOLD_MS, 0, 1);
    noFill();
    stroke(220, 55, 55);
    strokeWeight(5);
    arc(cx, cy, centerRadius * 2 + 14, centerRadius * 2 + 14,
        -HALF_PI, -HALF_PI + TWO_PI * t);
    noStroke();
    // Re-fill centre so arc doesn't bleed through
    fill(15, 18, 28);
    ellipse(cx, cy, centerRadius * 2 - 2, centerRadius * 2 - 2);
  }

  // ── Current letter large in centre ──
  fill(255, 185, 30);
  textFont(fontHuge);
  textAlign(CENTER);
  text(("" + alphabet.charAt(topIdx)).toUpperCase(), cx, cy + 18);

  // ── Fixed pointer at 12 o'clock (outside the ring, anchored to watch face) ──
  fill(210, 45, 45);
  triangle(cx - 10, cy - discRadius - 3,
           cx + 10, cy - discRadius - 3,
           cx,      cy - discRadius + 16);

  // ── Subtle spin-direction arrows below the disc ──
  fill(120);
  textFont(fontSmall);
  textAlign(CENTER);
  text("\u2190 spin \u2192", cx, cy + discRadius + 15);
}

// ── NEXT button (outside the 1″ area) ────────────────────────────────────────
void drawNextButton() {
  fill(45, 155, 75);
  rect(620, 640, 160, 55, 8);
  fill(255);
  textFont(fontMed);
  textAlign(CENTER);
  text("NEXT >", 700, 677);
}

void drawHints() {
  float by = height/2 + sizeOfInputArea/2 + 16;
  fill(130);
  textFont(fontSmall);
  textAlign(CENTER);
  text("tap ring = type letter   |   tap centre = space   |   hold centre = backspace", width/2, by);
}

// ── Input handling ────────────────────────────────────────────────────────────
void mousePressed() {
  if (startTime == 0) return;

  // NEXT button
  if (mouseX >= 620 && mouseX <= 780 && mouseY >= 640 && mouseY <= 695) {
    nextTrial();
    return;
  }

  float cx = width / 2.0;
  float cy = height / 2.0;
  pressStartDist = dist(mouseX, mouseY, cx, cy);

  if (pressStartDist <= discRadius) {
    prevMouseAngle = atan2(mouseY - cy, mouseX - cx);
    dragging       = true;
    totalDragAngle = 0;
    snapping       = false;

    // Start hold timer if press is on the centre
    if (pressStartDist <= centerRadius) {
      holdActive    = true;
      backspaceUsed = false;
      holdStartTime = millis();
    } else {
      holdActive = false;
    }
  }
}

void mouseDragged() {
  if (!dragging) return;

  // Any drag cancels the hold
  holdActive = false;

  float cx  = width / 2.0;
  float cy  = height / 2.0;
  float cur = atan2(mouseY - cy, mouseX - cx);
  float delta = cur - prevMouseAngle;

  // Clamp wrap-around at ±π
  if (delta >  PI) delta -= TWO_PI;
  if (delta < -PI) delta += TWO_PI;

  dialAngle      -= delta;   // anticlockwise = advancing alphabet
  totalDragAngle += abs(delta);
  prevMouseAngle  = cur;
}

void mouseReleased() {
  if (!dragging) return;
  dragging = false;

  boolean wasHold = holdActive;
  holdActive = false;

  // If backspace already fired from hold, just snap and exit
  if (backspaceUsed) {
    backspaceUsed = false;
    snapDial();
    return;
  }

  if (totalDragAngle < 0.2) {
    // Tap gesture — commit an action
    if (pressStartDist <= centerRadius) {
      currentTyped += " ";               // centre tap → space
    } else {
      currentTyped += alphabet.charAt(topLetterIndex()); // ring tap → type top letter
    }
  }

  snapDial(); // always snap to clean letter position after gesture
}

void snapDial() {
  targetDialAngle = round(dialAngle / slotAngle) * slotAngle;
  snapping = true;
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
