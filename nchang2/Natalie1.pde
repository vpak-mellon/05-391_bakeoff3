import java.util.Arrays;
import java.util.Collections;
import java.util.Random;

// Set the DPI to make your smartwatch 1 inch square. Measure it on the screen
final int DPIofYourDeviceScreen = 100; //you will need to look up the DPI or PPI of your device to make sure you get the right scale!!
//http://en.wikipedia.org/wiki/List_of_displays_by_pixel_density

//Do not change the following variables
String[] phrases; //contains all of the phrases
int totalTrialNum = 3 + (int)random(3); //the total number of phrases to be tested - set this low for testing. Might be ~10 for the real bakeoff!
int currTrialNum = 0; // the current trial number (indexes into trials array above)
float startTime = 0; // time starts when the first letter is entered
float finishTime = 0; // records the time of when the final trial ends
float lastTime = 0; //the timestamp of when the last trial was completed
float lettersEnteredTotal = 0; //a running total of the number of letters the user has entered (need this for final WPM computation)
float lettersExpectedTotal = 0; //a running total of the number of letters expected (correct phrases)
float errorsTotal = 0; //a running total of the number of errors (when hitting next)
String currentPhrase = ""; //the current target phrase
String currentTyped = ""; //what the user has typed so far
final float sizeOfInputArea = DPIofYourDeviceScreen*1; //aka, 1.0 inches square!
PImage watch;
PImage mouseCursor;
float cursorHeight;
float cursorWidth;

// Carousel state
boolean carouselOpen = false;
int activeGroup = -1; // which alphabet group opened the carousel

// 4 alphabet groups split as evenly as possible (26 letters → 7,7,6,6)
String[] groups = {"abcdefg", "hijklmn", "opqrst", "uvwxyz"};
String[] groupLabels = {"A-G", "H-N", "O-T", "U-Z"};

// Layout constants — all relative to watch face center
float cx, cy; // center of watch face
float carouselRadius; // distance of letter buttons from center in carousel

void setup()
{
  watch = loadImage("watchhand3smaller.png");
  phrases = loadStrings("phrases2.txt");
  Collections.shuffle(Arrays.asList(phrases), new Random());

  orientation(LANDSCAPE);
  size(800, 800);
  textFont(createFont("Arial", 24));
  noStroke();

  noCursor();
  mouseCursor = loadImage("finger.png");
  cursorHeight = DPIofYourDeviceScreen * (400.0/250.0);
  cursorWidth = cursorHeight * 0.6;
}

void draw()
{
  background(255);
  drawWatch();
  fill(100);
  rect(width/2-sizeOfInputArea/2, height/2-sizeOfInputArea/2, sizeOfInputArea, sizeOfInputArea);

  cx = width / 2;
  cy = height / 2;
  carouselRadius = sizeOfInputArea * 0.40;

  if (finishTime!=0)
  {
    fill(128);
    textAlign(CENTER);
    text("Finished", 280, 150);
    cursor(ARROW);
    return;
  }

  if (startTime==0 & !mousePressed)
  {
    fill(128);
    textAlign(CENTER);
    text("Click to start time!", 280, 150);
  }

  if (startTime==0 & mousePressed)
  {
    nextTrial();
  }

  if (startTime!=0)
  {
    textAlign(LEFT);
    fill(128);
    text("Phrase " + (currTrialNum+1) + " of " + totalTrialNum, 70, 50);
    fill(128);
    text("Target:   " + currentPhrase, 70, 100);
    text("Entered:  " + currentTyped +"|", 70, 140);

    fill(255, 0, 0);
    rect(600, 600, 200, 200);
    fill(255);
    text("NEXT > ", 650, 650);

    if (!carouselOpen) {
      drawMainButtons();
    } else {
      drawCarousel();
    }
  }

  image(mouseCursor, mouseX+cursorWidth/2-cursorWidth/3, mouseY+cursorHeight/2-cursorHeight/5, cursorWidth, cursorHeight);
}

boolean didMouseClick(float x, float y, float w, float h)
{
  return (mouseX > x && mouseX<x+w && mouseY>y && mouseY<y+h);
}

boolean isHovering(float x, float y, float w, float h)
{
  return (mouseX > x && mouseX < x+w && mouseY > y && mouseY < y+h);
}

boolean isHoveringCircle(float bx, float by, float r)
{
  return dist(mouseX, mouseY, bx, by) <= r;
}

// Draws the 6 main buttons on the watch face (4 alphabet groups + space + delete)
// The top 4 buttons are inset by a margin so they stay within the black watch face area
void drawMainButtons()
{
  float iax = cx - sizeOfInputArea/2;
  float iay = cy - sizeOfInputArea/2;
  float iaw = sizeOfInputArea;
  float iah = sizeOfInputArea;

  float rowH = iah / 3.0;
  float colW = iaw / 2.0;

  // All 6 buttons now use the same full-cell size (same as DEL/SPACE)
  for (int row = 0; row < 2; row++) {
    for (int col = 0; col < 2; col++) {
      int gIdx = row * 2 + col;
      float bx = iax + col * colW;
      float by = iay + row * rowH;
      color btnColor = isHovering(bx, by, colW, rowH) ? color(60, 200, 90) : color(70, 120, 200);
      drawGroupBtn(bx, by, colW, rowH, gIdx, btnColor);
    }
  }

  color delColor   = isHovering(iax,        iay + 2*rowH, colW, rowH) ? color(60, 200, 90) : color(190, 70, 70);
  color spaceColor = isHovering(iax + colW, iay + 2*rowH, colW, rowH) ? color(60, 200, 90) : color(60, 150, 90);

  drawActionBtn(iax,        iay + 2*rowH, colW, rowH, "DEL",   delColor);
  drawActionBtn(iax + colW, iay + 2*rowH, colW, rowH, "SPACE", spaceColor);
}

void drawGroupBtn(float x, float y, float w, float h, int gIdx, color c)
{
  fill(c);
  rect(x + 3, y + 3, w - 6, h - 6, 8);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(14);
  text(groupLabels[gIdx], x + w/2, y + h*0.4);
  textSize(10);
  fill(200, 230, 255);
  text(groups[gIdx], x + w/2, y + h*0.7);
}

void drawActionBtn(float x, float y, float w, float h, String label, color c)
{
  fill(c);
  rect(x + 3, y + 3, w - 6, h - 6, 8);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(16);
  text(label, x + w/2, y + h/2);
}

void drawCarousel()
{
  fill(0, 0, 0, 180);
  rect(width/2 - sizeOfInputArea/2, height/2 - sizeOfInputArea/2, sizeOfInputArea, sizeOfInputArea, 12);

  String letters = groups[activeGroup];
  int n = letters.length();

  float safeRadius = sizeOfInputArea * 0.36;
  float bSize = sizeOfInputArea * 0.24;
  float hitSize = bSize * 1.4;

  String hoveredLetter = "";

  for (int i = 0; i < n; i++) {
    float angle = TWO_PI / n * i - HALF_PI;
    float bx = cx + cos(angle) * safeRadius;
    float by = cy + sin(angle) * safeRadius;

    boolean hovered = isHovering(bx - hitSize/2, by - hitSize/2, hitSize, hitSize);
    if (hovered) hoveredLetter = "" + letters.charAt(i);

    color btnColor = hovered ? color(60, 220, 90) : color(100, 150, 255, 230);
    fill(btnColor);
    rect(bx - bSize/2, by - bSize/2, bSize, bSize, 6);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(18);
    text("" + letters.charAt(i), bx, by);
  }

  if (!hoveredLetter.equals("")) {
    fill(255, 220, 0);
    textAlign(CENTER, CENTER);
    textSize(36);
    text(hoveredLetter, cx, cy);
  } else {
    float cSize = sizeOfInputArea * 0.20;
    color closeColor = isHoveringCircle(cx, cy, cSize/2) ? color(60, 200, 90) : color(190, 70, 70, 240);
    fill(closeColor);
    ellipse(cx, cy, cSize, cSize);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(12);
    text("CLOSE", cx, cy);
  }
}

void mousePressed()
{
  if (startTime == 0) return;

  if (didMouseClick(600, 600, 200, 200))
  {
    nextTrial();
    return;
  }

  if (carouselOpen)
  {
    float cSize = sizeOfInputArea * 0.20;
    if (dist(mouseX, mouseY, cx, cy) <= cSize / 2)
    {
      carouselOpen = false;
      activeGroup = -1;
      return;
    }

    String letters = groups[activeGroup];
    int n = letters.length();
    float safeRadius = sizeOfInputArea * 0.36;
    float bSize = sizeOfInputArea * 0.24;
    float hitSize = bSize * 1.4;

    for (int i = 0; i < n; i++)
    {
      float angle = TWO_PI / n * i - HALF_PI;
      float bx = cx + cos(angle) * safeRadius;
      float by = cy + sin(angle) * safeRadius;

      if (mouseX > bx - hitSize/2 && mouseX < bx + hitSize/2 &&
          mouseY > by - hitSize/2 && mouseY < by + hitSize/2)
      {
        currentTyped += letters.charAt(i);
        carouselOpen = false;
        activeGroup = -1;
        return;
      }
    }
    carouselOpen = false;
    activeGroup = -1;
    return;
  }

  float iax = cx - sizeOfInputArea/2;
  float iay = cy - sizeOfInputArea/2;
  float iaw = sizeOfInputArea;
  float iah = sizeOfInputArea;
  float rowH = iah / 3.0;
  float colW = iaw / 2.0;

  if (mouseY > iay + 2*rowH && mouseY < iay + iah)
  {
    if (mouseX > iax && mouseX < iax + colW)
    {
      if (currentTyped.length() > 0)
        currentTyped = currentTyped.substring(0, currentTyped.length() - 1);
      return;
    }
    if (mouseX > iax + colW && mouseX < iax + iaw)
    {
      currentTyped += " ";
      return;
    }
  }

  for (int row = 0; row < 2; row++)
  {
    for (int col = 0; col < 2; col++)
    {
      int gIdx = row * 2 + col;
      float bx = iax + col * colW;
      float by = iay + row * rowH;
      if (mouseX > bx && mouseX < bx + colW && mouseY > by && mouseY < by + rowH)
      {
        activeGroup = gIdx;
        carouselOpen = true;
        return;
      }
    }
  }
}

void nextTrial()
{
  if (currTrialNum >= totalTrialNum)
    return;

  if (startTime!=0 && finishTime==0)
  {
    System.out.println("==================");
    System.out.println("Phrase " + (currTrialNum+1) + " of " + totalTrialNum);
    System.out.println("Target phrase: " + currentPhrase);
    System.out.println("Phrase length: " + currentPhrase.length());
    System.out.println("User typed: " + currentTyped);
    System.out.println("User typed length: " + currentTyped.length());
    System.out.println("Number of errors: " + computeLevenshteinDistance(currentTyped.trim(), currentPhrase.trim()));
    System.out.println("Time taken on this trial: " + (millis()-lastTime));
    System.out.println("Time taken since beginning: " + (millis()-startTime));
    System.out.println("==================");
    lettersExpectedTotal+=currentPhrase.trim().length();
    lettersEnteredTotal+=currentTyped.trim().length();
    errorsTotal+=computeLevenshteinDistance(currentTyped.trim(), currentPhrase.trim());
  }

  if (currTrialNum == totalTrialNum-1)
  {
    finishTime = millis();
    System.out.println("==================");
    System.out.println("Trials complete!");
    System.out.println("Total time taken: " + (finishTime - startTime));
    System.out.println("Total letters entered: " + lettersEnteredTotal);
    System.out.println("Total letters expected: " + lettersExpectedTotal);
    System.out.println("Total errors entered: " + errorsTotal);

    float wpm = (lettersEnteredTotal/5.0f)/((finishTime - startTime)/60000f);
    float freebieErrors = lettersExpectedTotal*.05;
    float penalty = max(errorsTotal-freebieErrors, 0) * .5f;

    System.out.println("Raw WPM: " + wpm);
    System.out.println("Freebie errors: " + freebieErrors);
    System.out.println("Penalty: " + penalty);
    System.out.println("WPM w/ penalty: " + (wpm-penalty));
    System.out.println("==================");

    currTrialNum++;
    return;
  }

  if (startTime==0)
  {
    System.out.println("Trials beginning! Starting timer...");
    startTime = millis();
  }
  else
    currTrialNum++;

  lastTime = millis();
  currentTyped = "";
  currentPhrase = phrases[currTrialNum];
  carouselOpen = false;
  activeGroup = -1;
}

void drawWatch()
{
  float watchscale = DPIofYourDeviceScreen/138.0;
  pushMatrix();
  translate(width/2, height/2);
  scale(watchscale);
  imageMode(CENTER);
  image(watch, 0, 0);
  popMatrix();
}

int computeLevenshteinDistance(String phrase1, String phrase2)
{
  int[][] distance = new int[phrase1.length() + 1][phrase2.length() + 1];

  for (int i = 0; i <= phrase1.length(); i++)
    distance[i][0] = i;
  for (int j = 1; j <= phrase2.length(); j++)
    distance[0][j] = j;

  for (int i = 1; i <= phrase1.length(); i++)
    for (int j = 1; j <= phrase2.length(); j++)
      distance[i][j] = min(min(distance[i - 1][j] + 1, distance[i][j - 1] + 1), distance[i - 1][j - 1] + ((phrase1.charAt(i - 1) == phrase2.charAt(j - 1)) ? 0 : 1));

  return distance[phrase1.length()][phrase2.length()];
}
