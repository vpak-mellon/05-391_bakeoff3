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

// ── Arc Dial design ──────────────────────────────────────────────────────────
//  Only the top arc of a large imaginary disc is visible.
//  The selected letter sits at 12 o'clock, shown huge in the centre.
//  Adjacent letters fan out left/right along the arc, shrinking with distance.
//  Drag left/right on the arc to spin. Tap the arc (small drag) to type.
//  Space button: left side of watch face
//  Backspace button: right side of watch face

String alphabet   = "abcdefghijklmnopqrstuvwxyz";
int    numLetters = 26;

// The imaginary disc center is well below the watch center so only the top
// arc peeks into view.
float discR;       // radius of the imaginary disc — set in setup
float discCY;      // Y of the disc center (below watch center)

// Rotation state (in letter-index units × slotAngle = radians)
float  slotAngle  = radians(22);  // degrees between adjacent letters on the arc
float  dialAngle  = 0;            // accumulated angle (unbounded)
float  targetDialAngle = 0;
boolean snapping  = false;

// Drag state
float   prevMouseX    = 0;
boolean dragging      = false;
float   totalDragPx   = 0;

// Backspace hold
float   holdStartTime = 0;
boolean holdActive    = false;
boolean backspaceUsed = false;
final float HOLD_MS   = 450;

// Side-button geometry (set in setup)
float sideBtnW, sideBtnH, sideBtnY;

PFont fontHuge, fontLarge, fontMed, fontSmall;

// ── Setup ─────────────────────────────────────────────────────────────────────
void setup() {
  watch = loadImage("watchhand3smaller.png");
  phrases = loadStrings("phrases2.txt");
  Collections.shuffle(Arrays.asList(phrases), new Random());

  orientation(LANDSCAPE);
  size(800, 800);

  fontHuge  = createFont("Arial Bold", 110);
  fontLarge = createFont("Arial", 36);
  fontMed   = createFont("Arial", 20);
  fontSmall = createFont("Arial", 13);

  noStroke();
  noCursor();
  mouseCursor  = loadImage("finger.png");
  cursorHeight = DPIofYourDeviceScreen * (400.0 / 250.0);
  cursorWidth  = cursorHeight * 0.6;

  // Disc is large; its center sits above the watch face so only the bottom arc shows
  discR  = sizeOfInputArea * 1.4;
  discCY = height / 2.0 - discR * 0.72;

  // Side buttons: vertically centered in the watch face, flanking the letter
  sideBtnW = sizeOfInputArea * 0.26;
  sideBtnH = sizeOfInputArea * 0.38;
  sideBtnY = height / 2.0 - sideBtnH / 2.0 - sizeOfInputArea * 0.04;
}

// ── Helpers ───────────────────────────────────────────────────────────────────
int topLetterIndex() {
  int idx = ((int) round(dialAngle / slotAngle)) % numLetters;
  if (idx < 0) idx += numLetters;
  return idx;
}

// Returns the (x, y) of a point on the imaginary disc at angle a
float[] discPoint(float a) {
  float cx = width / 2.0;
  return new float[]{ cx + discR * sin(a), discCY - discR * cos(a) };
}

// ── Draw ──────────────────────────────────────────────────────────────────────
void draw() {
  background(225);
  drawWatch();

  // Watch face background
  fill(15, 18, 28);
  rect(width/2 - sizeOfInputArea/2, height/2 - sizeOfInputArea/2,
       sizeOfInputArea, sizeOfInputArea);

  // Snap animation
  if (!dragging && snapping) {
    dialAngle += (targetDialAngle - dialAngle) * 0.20;
    if (abs(targetDialAngle - dialAngle) < 0.001) {
      dialAngle = targetDialAngle;
      snapping  = false;
    }
  }

  // Backspace hold trigger
  if (holdActive && !backspaceUsed && millis() - holdStartTime >= HOLD_MS) {
    if (currentTyped.length() > 0)
      currentTyped = currentTyped.substring(0, currentTyped.length() - 1);
    backspaceUsed = true;
  }

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
    drawSideButtons();
    drawArc();
    drawNextButton();
  }

  image(mouseCursor,
        mouseX + cursorWidth/2 - cursorWidth/3,
        mouseY + cursorHeight/2 - cursorHeight/5,
        cursorWidth, cursorHeight);
}

// ── Text area (above watch) ───────────────────────────────────────────────────
void drawTextArea() {
  float topY = height/2 - sizeOfInputArea/2;
  float lx   = 20;

  textFont(fontSmall); textAlign(LEFT); fill(110);
  text("Phrase " + (currTrialNum + 1) + " of " + totalTrialNum, lx, topY - 78);

  fill(80); textFont(fontMed);
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

  fill(30); textFont(fontMed);
  text("Typed:  " + currentTyped + "|", lx, topY - 18);
}

// ── Side buttons (inside watch face) ─────────────────────────────────────────
void drawSideButtons() {
  float watchL = width/2 - sizeOfInputArea/2;
  float watchR = width/2 + sizeOfInputArea/2;

  // Backspace — left
  boolean bsHeld = holdActive && !backspaceUsed;
  float   bsProg = bsHeld ? constrain((millis() - holdStartTime) / HOLD_MS, 0, 1) : 0;
  fill(bsHeld ? lerpColor(color(50, 80, 180), color(210, 45, 45), bsProg) : color(50, 80, 180));
  rect(watchL, sideBtnY, sideBtnW, sideBtnH, 0, 8, 8, 0);
  fill(255); textFont(fontSmall); textAlign(CENTER);
  text("⌫", watchL + sideBtnW / 2, sideBtnY + sideBtnH / 2 + 5);

  // Space — right
  fill(color(40, 140, 90));
  rect(watchR - sideBtnW, sideBtnY, sideBtnW, sideBtnH, 8, 0, 0, 8);
  fill(255); textFont(fontSmall); textAlign(CENTER);
  text("SPC", watchR - sideBtnW / 2, sideBtnY + sideBtnH / 2 + 5);
}

// ── Arc of letters ────────────────────────────────────────────────────────────
void drawArc() {
  float cx    = width / 2.0;
  float cy    = height / 2.0;
  int   topIdx = topLetterIndex();

  // How many neighbours to show on each side
  int sideCount = 2; // total visible = 2*sideCount+1 = 5

  // Draw neighbours first (back to front so centre is on top)
  for (int pass = sideCount; pass >= 0; pass--) {
    for (int side = (pass == 0 ? 0 : -1); side <= 1; side += (pass == 0 ? 1 : 2)) {
      int k = pass * side;
      drawLetterOnArc(topIdx, k, sideCount);
    }
  }

  // Selected letter fills the centre of the watch face, huge
  fill(255, 185, 30);
  textFont(fontHuge);
  textAlign(CENTER);
  char sel = alphabet.charAt(topIdx);
  // Vertically: sit in upper-centre of watch
  text(("" + sel).toUpperCase(), cx, cy + 28);
}

void drawLetterOnArc(int topIdx, int k, int sideCount) {
  float cx    = width / 2.0;

  // k=0 is centre, ±1, ±2 are neighbours
  // Angle offset from 12 o'clock
  float angleOffset = k * slotAngle - (dialAngle - round(dialAngle / slotAngle) * slotAngle);
  // Point on arc
  float[] pt = discPoint(angleOffset);
  float px = pt[0];
  float py = pt[1];

  if (k == 0) return; // centre letter drawn separately as huge text

  // Size + alpha fade by distance
  float t     = (float) abs(k) / (sideCount + 0.5);
  float fsize = lerp(28, 13, t);
  float alpha = lerp(220, 60, t);

  int letterIdx = ((topIdx + k) % numLetters + numLetters) % numLetters;
  char ch = alphabet.charAt(letterIdx);

  // Small rounded pill background
  float pw = fsize * 1.5;
  float ph = fsize * 1.6;
  fill(38, 62, 128, alpha * 0.8);
  rect(px - pw/2, py - ph/2, pw, ph, 6);

  // Letter
  textFont(createFont("Arial", fsize));
  textAlign(CENTER);
  fill(200, alpha);
  text(("" + ch).toUpperCase(), px, py + fsize * 0.35);
}

// ── NEXT button ───────────────────────────────────────────────────────────────
void drawNextButton() {
  fill(45, 155, 75);
  rect(620, 640, 160, 55, 8);
  fill(255); textFont(fontMed); textAlign(CENTER);
  text("NEXT >", 700, 677);
}

// ── Side button hit test ──────────────────────────────────────────────────────
boolean inBackspace(float x, float y) {
  float watchL = width/2 - sizeOfInputArea/2;
  return x >= watchL && x <= watchL + sideBtnW &&
         y >= sideBtnY && y <= sideBtnY + sideBtnH;
}

boolean inSpace(float x, float y) {
  float watchR = width/2 + sizeOfInputArea/2;
  return x >= watchR - sideBtnW && x <= watchR &&
         y >= sideBtnY && y <= sideBtnY + sideBtnH;
}

boolean inWatchFace(float x, float y) {
  return x >= width/2 - sizeOfInputArea/2 && x <= width/2 + sizeOfInputArea/2 &&
         y >= height/2 - sizeOfInputArea/2 && y <= height/2 + sizeOfInputArea/2;
}

// ── Input ─────────────────────────────────────────────────────────────────────
void mousePressed() {
  if (startTime == 0) return;

  if (mouseX >= 620 && mouseX <= 780 && mouseY >= 640 && mouseY <= 695) {
    nextTrial(); return;
  }

  // Space button
  if (inSpace(mouseX, mouseY)) {
    currentTyped += " "; return;
  }

  // Backspace button — start hold
  if (inBackspace(mouseX, mouseY)) {
    holdActive    = true;
    backspaceUsed = false;
    holdStartTime = millis();
    prevMouseX    = mouseX;
    dragging      = false;
    totalDragPx   = 0;
    return;
  }

  // Arc area — start drag
  if (inWatchFace(mouseX, mouseY)) {
    prevMouseX  = mouseX;
    dragging    = true;
    totalDragPx = 0;
    holdActive  = false;
    snapping    = false;
  }
}

void mouseDragged() {
  if (inBackspace(mouseX, mouseY) && holdActive) return; // let hold run

  // Cancel hold if user moves away
  if (holdActive && !inBackspace(mouseX, mouseY)) holdActive = false;

  if (!dragging) return;

  float dx = mouseX - prevMouseX;
  // Drag left → advance alphabet (anticlockwise), drag right → go back
  float sensitivity = 0.012;
  dialAngle      -= dx * sensitivity;
  totalDragPx    += abs(dx);
  prevMouseX      = mouseX;
}

void mouseReleased() {
  holdActive = false;

  if (backspaceUsed) { backspaceUsed = false; snapDial(); return; }

  if (dragging && totalDragPx < 8) {
    // Tap on arc → type current letter
    currentTyped += alphabet.charAt(topLetterIndex());
  }

  dragging = false;
  snapDial();
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
