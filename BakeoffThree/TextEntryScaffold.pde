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

// ── 6-zone drag design ────────────────────────────────────────────────────────
//  3 columns × 2 rows = 6 zones, ~4-5 letters each.
//  Press in a zone, drag left/right to pick letter, release to commit.
//  Letters shown at top of each zone. DEL/SPC strip at bottom.
//
//  Zone layout:
//    0: a b c d e   1: f g h i j   2: k l m n
//    3: o p q r s   4: t u v w     5: x y z ⎵(spc)  ← space as last item

String[] groups = { "abcd", "efgh", "ijkl", "mnopq", "rstu", "vwxyz" };

int   activeGroup  = -1;
int   activeLetIdx = 0;
float btnStripH, previewH;
float watchL, watchR, watchT, watchB;
float zoneW, zoneH;  // size of each zone (2 cols, 3 rows)
float zonesT;        // y where zones begin (after preview strip)

PFont fontHuge, fontLarge, fontMed, fontSmall, fontScaffold;

color[] zColor = {
  color(35, 60, 130),  color(75, 35, 120),  color(25, 100, 85),
  color(115, 55, 25),  color(30, 95, 50),   color(95, 30, 60)
};

void setup() {
  watch = loadImage("watchhand3smaller.png");
  phrases = loadStrings("phrases2.txt");
  Collections.shuffle(Arrays.asList(phrases), new Random());
  orientation(LANDSCAPE);
  size(800, 800);

  fontScaffold = createFont("Arial", 24);
  fontHuge     = createFont("Arial Bold", 82);
  fontLarge    = createFont("Arial Bold", 22);
  fontMed      = createFont("Arial", 17);
  fontSmall    = createFont("Arial", 11);
  textFont(fontScaffold);

  noStroke(); noCursor();
  mouseCursor  = loadImage("finger.png");
  cursorHeight = DPIofYourDeviceScreen * (400.0 / 250.0);
  cursorWidth  = cursorHeight * 0.6;

  float half  = sizeOfInputArea / 2.0;
  btnStripH   = sizeOfInputArea * 0.14;
  watchL      = width  / 2.0 - half;
  watchR      = width  / 2.0 + half;
  watchT      = height / 2.0 - half;
  watchB      = height / 2.0 + half;
  previewH    = sizeOfInputArea * 0.14;
  zonesT      = watchT + previewH;
  zoneW       = sizeOfInputArea / 2.0;
  zoneH       = (watchB - btnStripH - zonesT) / 3.0;
}

// ── Draw ──────────────────────────────────────────────────────────────────────
void draw() {
  background(225);
  drawWatch();

  // Watch face background
  fill(15, 18, 28);
  rect(watchL, watchT, sizeOfInputArea, sizeOfInputArea);

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
    drawZones();
    drawStrip();
    drawNextButton();
  }

  image(mouseCursor,
        mouseX + cursorWidth/2 - cursorWidth/3,
        mouseY + cursorHeight/2 - cursorHeight/5,
        cursorWidth, cursorHeight);
}

// ── Text area (original scaffold format) ─────────────────────────────────────
void drawTextArea() {
  textFont(fontScaffold);
  textAlign(LEFT);
  fill(128);
  text("Phrase " + (currTrialNum+1) + " of " + totalTrialNum, 70, 50);
  fill(128);
  text("Target:   " + currentPhrase, 70, 100);
  text("Entered:  " + currentTyped + "|", 70, 140);
}

// ── Six zones (2 cols × 3 rows) ──────────────────────────────────────────────
void drawZones() {
  // Preview strip at top — shows active letter above finger
  fill(30, 34, 48);
  rect(watchL, watchT, sizeOfInputArea, previewH);
  if (activeGroup >= 0) {
    String grp = groups[activeGroup];
    int n = grp.length();
    float slotW = sizeOfInputArea / n;
    for (int i = 0; i < n; i++) {
      float lx = watchL + slotW * i + slotW / 2.0;
      char c = grp.charAt(i);
      if (i == activeLetIdx) {
        fill(255, 185, 30);
        textFont(fontLarge);
      } else {
        fill(160, 120);
        textFont(fontSmall);
      }
      textAlign(CENTER);
      text((c == ' ') ? "SPC" : ("" + c).toUpperCase(), lx, watchT + previewH * 0.7);
    }
  }

  for (int g = 0; g < 6; g++) {
    int   col  = g % 2;
    int   row  = g / 2;
    float x0   = watchL + col * zoneW;
    float y0   = zonesT + row * zoneH;
    float x1   = x0 + zoneW;
    float y1   = y0 + zoneH;
    float cx   = (x0 + x1) / 2.0;
    float cy   = (y0 + y1) / 2.0;
    String grp = groups[g];
    int    n   = grp.length();
    boolean active = (activeGroup == g);

    // Background
    if (active) fill(lerpColor(zColor[g], color(255, 185, 30), 0.25));
    else        fill(zColor[g]);
    rect(x0, y0, zoneW, zoneH);

    // Divider lines
    stroke(15, 18, 28, 80); strokeWeight(1);
    if (col > 0) line(x0, y0, x0, y1);
    if (row > 0) line(x0, y0, x1, y0);
    noStroke();

    // Zone label (always shown — range or active letter)
    textAlign(CENTER);
    char first = grp.charAt(0);
    char last  = grp.charAt(n - 1);
    if (active) {
      fill(255, 185, 30);
      textFont(fontLarge);
      char ch = grp.charAt(activeLetIdx);
      text((ch == ' ') ? "SPC" : ("" + ch).toUpperCase(), cx, cy + 8);
    } else {
      fill(200, 160);
      textFont(fontMed);
      String label = ("" + first).toUpperCase() + "–" +
                     ((last == ' ') ? "SPC" : ("" + last).toUpperCase());
      text(label, cx, cy + 8);
    }
  }
  textFont(fontScaffold);
}

// ── DEL / SPC strip ───────────────────────────────────────────────────────────
void drawStrip() {
  float y   = watchB - btnStripH;
  float half = sizeOfInputArea / 2.0;
  float gap  = 4;
  float bw   = (sizeOfInputArea - gap) / 2.0;

  fill(140, 35, 35);
  rect(watchL, y, bw, btnStripH, 0, 0, 0, 5);
  fill(255); textFont(fontSmall); textAlign(CENTER);
  text("DEL", watchL + bw/2.0, y + btnStripH/2.0 + 4);

  fill(35, 110, 55);
  rect(watchL + bw + gap, y, bw, btnStripH, 0, 0, 5, 0);
  fill(255); textFont(fontSmall); textAlign(CENTER);
  text("SPACE", watchL + bw + gap + bw/2.0, y + btnStripH/2.0 + 4);

  textFont(fontScaffold);
}

// ── NEXT button ───────────────────────────────────────────────────────────────
void drawNextButton() {
  fill(255, 0, 0);
  rect(600, 600, 200, 200);
  fill(255); textFont(fontScaffold); textAlign(LEFT);
  text("NEXT > ", 650, 650);
}

// ── Helpers ───────────────────────────────────────────────────────────────────
// Which zone (0-5) does this point fall in? Returns -1 if none.
int groupAt(float x, float y) {
  if (x < watchL || x > watchR || y < zonesT || y >= watchB - btnStripH) return -1;
  int col = (x < watchL + zoneW) ? 0 : 1;
  int row = (int)constrain((y - zonesT) / zoneH, 0, 2);
  return row * 2 + col;
}

// Letter index within a zone based on x position
int letterIdxAt(int g, float x) {
  float x0 = watchL + (g % 2) * zoneW;
  float t   = constrain((x - x0) / zoneW, 0, 0.9999);
  return (int)(t * groups[g].length());
}

boolean inStrip(float x, float y) {
  return y >= watchB - btnStripH && y <= watchB && x >= watchL && x <= watchR;
}

// ── Input ─────────────────────────────────────────────────────────────────────
void mousePressed() {
  if (startTime == 0) return;

  // NEXT
  if (mouseX >= 600 && mouseX <= 800 && mouseY >= 600 && mouseY <= 800) {
    nextTrial(); activeGroup = -1; return;
  }

  // DEL / SPC strip — commit on press
  if (inStrip(mouseX, mouseY)) {
    float bw = (sizeOfInputArea - 4) / 2.0;
    if (mouseX <= watchL + bw) {
      if (currentTyped.length() > 0)
        currentTyped = currentTyped.substring(0, currentTyped.length() - 1);
    } else {
      currentTyped += " ";
    }
    activeGroup = -1;
    return;
  }

  // Start drag — activate the quadrant under the finger
  int g = groupAt(mouseX, mouseY);
  if (g >= 0) {
    activeGroup  = g;
    activeLetIdx = letterIdxAt(g, mouseX);
  }
}

void mouseMoved() {
  // Hover with no button: update preview only
  int g = groupAt(mouseX, mouseY);
  if (g >= 0) {
    activeGroup  = g;
    activeLetIdx = letterIdxAt(g, mouseX);
  } else {
    activeGroup = -1;
  }
}

void mouseDragged() {
  // Drag within quadrant scrolls the letter selection
  int g = groupAt(mouseX, mouseY);
  if (g >= 0) {
    activeGroup  = g;
    activeLetIdx = letterIdxAt(g, mouseX);
  }
}

void mouseReleased() {
  if (startTime == 0) return;
  if (inStrip(mouseX, mouseY)) return; // strip handled on press
  // Commit whichever letter is selected
  if (activeGroup >= 0) {
    currentTyped += groups[activeGroup].charAt(activeLetIdx);
    activeGroup = -1;
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
