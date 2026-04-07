import java.util.Arrays;
import java.util.Collections;
import java.util.Random;
import java.util.HashMap;

// Set the DPI to make your smartwatch 1 inch square. Measure it on the screen
final int DPIofYourDeviceScreen = 250;

// Do not change the following variables
String[] phrases;       // contains all of the phrases
String[] suggestions;   // contains all of the phrases
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
final float sizeOfInputArea = DPIofYourDeviceScreen * 1; // 1 inch square
PImage watch;
PImage mouseCursor;
float cursorHeight;
float cursorWidth;

// ── Hable One / Braille input ────────────────────────────────────────────────
// Braille dot layout (Hable One button positions):
//   LEFT col | RIGHT col
//     1           4      (top)
//     2           5      (middle)
//     3           6      (bottom)

HashMap<String, Character> brailleMap;
boolean[] btnActive = new boolean[7]; // 1-indexed; buttons 1-6
float[]   btnX      = new float[7];
float[]   btnY      = new float[7];
float     btnRadius;
boolean   isInputting = false;

// Fonts
PFont fontLarge, fontSmall, fontMono;

void setup() {
  watch      = loadImage("watchhand3smaller.png");
  phrases    = loadStrings("phrases2.txt");
  Collections.shuffle(Arrays.asList(phrases), new Random());

  orientation(LANDSCAPE);
  size(800, 800);

  fontLarge = createFont("Arial", 28);
  fontSmall = createFont("Arial", 16);
  fontMono  = createFont("Courier", 22);

  noStroke();

  noCursor();
  mouseCursor  = loadImage("finger.png");
  cursorHeight = DPIofYourDeviceScreen * (400.0 / 250.0);
  cursorWidth  = cursorHeight * 0.6;

  setupBrailleMap();
  setupButtons();
}

// ── Braille mapping (Grade 1, a-z + space + backspace) ──────────────────────
void setupBrailleMap() {
  brailleMap = new HashMap<String, Character>();
  brailleMap.put("1",     'a');
  brailleMap.put("12",    'b');
  brailleMap.put("14",    'c');
  brailleMap.put("145",   'd');
  brailleMap.put("15",    'e');
  brailleMap.put("124",   'f');
  brailleMap.put("1245",  'g');
  brailleMap.put("125",   'h');
  brailleMap.put("24",    'i');
  brailleMap.put("245",   'j');
  brailleMap.put("13",    'k');
  brailleMap.put("123",   'l');
  brailleMap.put("134",   'm');
  brailleMap.put("1345",  'n');
  brailleMap.put("135",   'o');
  brailleMap.put("1234",  'p');
  brailleMap.put("12345", 'q');
  brailleMap.put("1235",  'r');
  brailleMap.put("234",   's');
  brailleMap.put("2345",  't');
  brailleMap.put("136",   'u');
  brailleMap.put("1236",  'v');
  brailleMap.put("2456",  'w');
  brailleMap.put("1346",  'x');
  brailleMap.put("13456", 'y');
  brailleMap.put("1356",  'z');
  brailleMap.put("456",   ' ');   // space
  brailleMap.put("12456", '\b');  // backspace
}

// ── Button positions inside the 1″ watch face ────────────────────────────────
void setupButtons() {
  float cx = width / 2.0;
  float cy = height / 2.0;

  btnRadius = sizeOfInputArea * 0.105; // ~26 px at 250 DPI

  float colOff  = sizeOfInputArea * 0.20;  // 50 px  — horizontal
  float rowStep = sizeOfInputArea * 0.28;  // 70 px  — vertical

  // Left column  (dots 1, 2, 3)
  btnX[1] = cx - colOff;  btnY[1] = cy - rowStep;
  btnX[2] = cx - colOff;  btnY[2] = cy;
  btnX[3] = cx - colOff;  btnY[3] = cy + rowStep;
  // Right column (dots 4, 5, 6)
  btnX[4] = cx + colOff;  btnY[4] = cy - rowStep;
  btnX[5] = cx + colOff;  btnY[5] = cy;
  btnX[6] = cx + colOff;  btnY[6] = cy + rowStep;
}

// ── Draw ─────────────────────────────────────────────────────────────────────
void draw() {
  background(240);

  drawWatch();

  // Dark watch-face background (the 1″ input area)
  fill(25, 28, 38);
  rect(width/2 - sizeOfInputArea/2, height/2 - sizeOfInputArea/2,
       sizeOfInputArea, sizeOfInputArea);

  // ── Finished screen ──
  if (finishTime != 0) {
    fill(60);
    textFont(fontLarge);
    textAlign(CENTER);
    text("Finished!", width/2, 200);
    cursor(ARROW);
    return;
  }

  // ── Pre-start screen ──
  if (startTime == 0 && !mousePressed) {
    fill(60);
    textFont(fontLarge);
    textAlign(CENTER);
    text("Tap anywhere to begin", width/2, 200);
  }
  if (startTime == 0 && mousePressed) {
    nextTrial();
  }

  // ── Trial UI ──
  if (startTime != 0) {
    drawTextArea();
    drawButtons();
    drawPreview();
    drawNextButton();
    drawLegend();
  }

  // Cursor always on top
  image(mouseCursor,
        mouseX + cursorWidth/2 - cursorWidth/3,
        mouseY + cursorHeight/2 - cursorHeight/5,
        cursorWidth, cursorHeight);
}

// Text display OUTSIDE the watch ─────────────────────────────────────────────
void drawTextArea() {
  float topY    = height/2 - sizeOfInputArea/2;  // top of watch face
  float leftX   = 20;

  // Phrase counter
  textFont(fontSmall);
  textAlign(LEFT);
  fill(100);
  text("Phrase " + (currTrialNum + 1) + " of " + totalTrialNum, leftX, topY - 80);

  // Target phrase — character-by-character colouring
  fill(80);
  textFont(fontMono);
  text("Target:", leftX, topY - 55);
  float tx = leftX + 100;
  for (int i = 0; i < currentPhrase.length(); i++) {
    char expected = currentPhrase.charAt(i);
    if (i < currentTyped.length()) {
      fill(currentTyped.charAt(i) == expected ? color(20, 160, 60) : color(200, 40, 40));
    } else {
      fill(80);
    }
    text("" + expected, tx, topY - 55);
    tx += textWidth("" + expected);
  }

  // Typed text
  fill(30);
  textFont(fontMono);
  text("Typed:  " + currentTyped + "|", leftX, topY - 20);
}

// Six Braille buttons on the watch face ──────────────────────────────────────
void drawButtons() {
  textFont(fontSmall);
  for (int i = 1; i <= 6; i++) {
    // Glow ring when active
    if (btnActive[i]) {
      noFill();
      stroke(255, 200, 50);
      strokeWeight(4);
      ellipse(btnX[i], btnY[i], btnRadius * 2 + 10, btnRadius * 2 + 10);
      noStroke();
    }

    // Button body
    if (btnActive[i]) {
      fill(255, 185, 30);   // active  — amber
    } else {
      fill(70, 120, 200);   // idle    — blue
    }
    ellipse(btnX[i], btnY[i], btnRadius * 2, btnRadius * 2);

    // Dot number
    fill(255);
    textAlign(CENTER);
    text("" + i, btnX[i], btnY[i] + 6);
  }
  noStroke();
}

// Letter preview above the watch ─────────────────────────────────────────────
void drawPreview() {
  if (!isInputting) return;

  String combo = getComboString();
  char   ch    = getCharForCombo(combo);

  String label;
  if      (ch == ' ')  label = "SPACE";
  else if (ch == '\b') label = "DEL";
  else if (ch != 0)    label = "" + Character.toUpperCase(ch);
  else if (!combo.isEmpty()) label = "dots " + combo + " — ?";
  else return;

  // Background pill
  float topY  = height/2 - sizeOfInputArea/2;
  float pillW = textWidth(label) + 40;
  float pillH = 38;
  float pillX = width/2 - pillW/2;
  float pillY = topY - pillH - 8;

  fill(ch != 0 ? color(255, 185, 30) : color(180, 60, 60));
  rect(pillX, pillY, pillW, pillH, 8);
  fill(30);
  textFont(fontLarge);
  textAlign(CENTER);
  text(label, width/2, pillY + pillH - 8);
}

// NEXT button (outside watch) ─────────────────────────────────────────────────
void drawNextButton() {
  fill(50, 170, 90);
  rect(620, 640, 160, 55, 8);
  fill(255);
  textFont(fontLarge);
  textAlign(CENTER);
  text("NEXT >", 700, 677);
}

// Compact braille reference to the right of the watch ────────────────────────
void drawLegend() {
  float rx = width/2 + sizeOfInputArea/2 + 18;
  float ry = height/2 - sizeOfInputArea/2 + 10;

  textFont(fontSmall);
  textAlign(LEFT);
  fill(90);
  text("Braille dots:", rx, ry + 14);
  text("1  4", rx + 6, ry + 34);
  text("2  5", rx + 6, ry + 52);
  text("3  6", rx + 6, ry + 70);
  fill(130);
  text("Hold + swipe", rx, ry + 96);
  text("to chord:", rx, ry + 112);
  text("456 = space", rx, ry + 132);
  text("12456 = del", rx, ry + 152);
}

// ── Helpers ──────────────────────────────────────────────────────────────────
String getComboString() {
  String s = "";
  for (int i = 1; i <= 6; i++) {
    if (btnActive[i]) s += i;
  }
  return s;
}

char getCharForCombo(String combo) {
  if (combo.isEmpty()) return 0;
  Character ch = brailleMap.get(combo);
  return (ch != null) ? (char) ch : 0;
}

boolean isOverButton(int btn) {
  float dx = mouseX - btnX[btn];
  float dy = mouseY - btnY[btn];
  return (dx * dx + dy * dy) <= btnRadius * btnRadius;
}

void commitCombo() {
  String combo = getComboString();
  char   ch    = getCharForCombo(combo);

  if (ch == ' ') {
    currentTyped += " ";
  } else if (ch == '\b') {
    if (currentTyped.length() > 0)
      currentTyped = currentTyped.substring(0, currentTyped.length() - 1);
  } else if (ch != 0) {
    currentTyped += ch;
  }

  for (int i = 1; i <= 6; i++) btnActive[i] = false;
  isInputting = false;
}

// ── Input events ─────────────────────────────────────────────────────────────
void mousePressed() {
  if (startTime == 0) return;

  // NEXT button
  if (mouseX >= 620 && mouseX <= 780 && mouseY >= 640 && mouseY <= 695) {
    nextTrial();
    return;
  }

  // Braille buttons
  for (int i = 1; i <= 6; i++) {
    if (isOverButton(i)) {
      btnActive[i] = true;
      isInputting  = true;
    }
  }
}

void mouseDragged() {
  if (!isInputting) return;
  for (int i = 1; i <= 6; i++) {
    if (isOverButton(i)) btnActive[i] = true;
  }
}

void mouseReleased() {
  if (!isInputting) return;
  commitCombo();
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
