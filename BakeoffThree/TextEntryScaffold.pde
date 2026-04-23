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

// ── T9 two-click design ───────────────────────────────────────────────────────
//  4 quadrant buttons fill the watch face (minus a bottom strip for DEL/SPC).
//  Letter groups:
//    TL: a b c d e f g   (7)
//    TR: h i j k l m     (6)
//    BL: n o p q r s     (6)
//    BR: t u v w x y z   (7)
//
//  Interaction:
//    1st click in a quadrant  → activates that group, letter set by x-position
//    hover after 1st click    → letter changes with finger x within the quadrant
//    2nd click (anywhere)     → commits the current letter
//    DEL / SPC strip          → instant tap, always accessible

String[] groups = { "abcdefg", "hijklm", "nopqrs", "tuvwxyz" };

int   activeGroup  = -1;   // which quadrant is active (-1 = idle)
int   activeLetIdx = 0;    // letter index within active group
float btnStripH;           // height of DEL/SPC strip at bottom
float watchL, watchR, watchT, watchB; // watch face edges
float midX, midY;          // centre of watch face
float quadH;               // height of each quadrant

PFont fontHuge, fontLarge, fontMed, fontSmall, fontScaffold;

// Quadrant colors (idle)
color[] qColor = { color(35, 60, 130), color(80, 35, 120),
                   color(30, 100, 80),  color(110, 55, 25) };

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
  midX        = width  / 2.0;
  midY        = watchT + (watchB - btnStripH - watchT) / 2.0;
  quadH       = (watchB - btnStripH - watchT) / 2.0;
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
    drawQuadrants();
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

// ── Four quadrants ────────────────────────────────────────────────────────────
void drawQuadrants() {
  // quadrant bounds: TL, TR, BL, BR
  float[][] qx = { {watchL, midX}, {midX, watchR}, {watchL, midX}, {midX, watchR} };
  float[][] qy = { {watchT, watchT+quadH}, {watchT, watchT+quadH},
                   {watchT+quadH, watchB-btnStripH}, {watchT+quadH, watchB-btnStripH} };

  for (int g = 0; g < 4; g++) {
    boolean active = (activeGroup == g);
    String  grp    = groups[g];
    int     n      = grp.length();
    float   x0 = qx[g][0], x1 = qx[g][1];
    float   y0 = qy[g][0], y1 = qy[g][1];
    float   qw = x1 - x0, qh = y1 - y0;
    float   cx = (x0 + x1) / 2.0, cy = (y0 + y1) / 2.0;

    // Background
    if (active) fill(lerpColor(qColor[g], color(255,185,30), 0.25));
    else        fill(qColor[g]);
    rect(x0, y0, qw, qh);

    // Thin divider lines
    stroke(15, 18, 28, 80); strokeWeight(1);
    if (g == 1 || g == 3) line(x0, y0, x0, y1); // vertical centre
    if (g == 2 || g == 3) line(x0, y0, x1, y0); // horizontal centre
    noStroke();

    if (active) {
      // Show hovered letter huge in centre
      fill(255, 185, 30);
      textFont(fontHuge);
      textAlign(CENTER);
      text(("" + grp.charAt(activeLetIdx)).toUpperCase(), cx, cy + 28);

      // Show all letters small across the top of the quadrant, highlight active
      textFont(fontSmall);
      float slotW = qw / n;
      for (int i = 0; i < n; i++) {
        float lx = x0 + slotW * i + slotW / 2.0;
        fill(i == activeLetIdx ? color(255,185,30) : color(200, 100));
        rect(x0 + slotW * i, y0, slotW, 3); // thin indicator bar
        fill(i == activeLetIdx ? color(255,185,30) : color(200, 140));
        text(("" + grp.charAt(i)).toUpperCase(), lx, y0 + 14);
      }

    } else {
      // Idle: show group range label
      fill(200, 160);
      textFont(fontLarge);
      textAlign(CENTER);
      String label = ("" + grp.charAt(0)).toUpperCase() + "–" +
                     ("" + grp.charAt(n-1)).toUpperCase();
      text(label, cx, cy + 8);
    }
  }
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
// Which group (0-3) does this point fall in? Returns -1 if none.
int groupAt(float x, float y) {
  if (x < watchL || x > watchR || y < watchT || y >= watchB - btnStripH) return -1;
  boolean left = (x < midX);
  boolean top  = (y < watchT + quadH);
  if (top  && left)  return 0;
  if (top  && !left) return 1;
  if (!top && left)  return 2;
  return 3;
}

// Letter index within a group based on x position inside that quadrant
int letterIdxAt(int g, float x) {
  float x0 = (g == 0 || g == 2) ? watchL : midX;
  float x1 = (g == 0 || g == 2) ? midX   : watchR;
  float t   = constrain((x - x0) / (x1 - x0), 0, 0.9999);
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

  // DEL / SPC strip
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

void mouseReleased() {
  if (startTime == 0) return;
  if (inStrip(mouseX, mouseY)) return;
  if (activeGroup >= 0) {
    currentTyped += groups[activeGroup].charAt(activeLetIdx);
    activeGroup = -1;
  }
}

void mouseMoved() {
  // Hover updates active group and letter continuously
  int g = groupAt(mouseX, mouseY);
  if (g >= 0) {
    activeGroup  = g;
    activeLetIdx = letterIdxAt(g, mouseX);
  } else {
    activeGroup = -1;
  }
}

void mouseDragged() {
  int g = groupAt(mouseX, mouseY);
  if (g >= 0) {
    activeGroup  = g;
    activeLetIdx = letterIdxAt(g, mouseX);
  } else {
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
