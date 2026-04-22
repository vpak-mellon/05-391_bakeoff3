import java.util.Arrays;
import java.util.Collections;
import java.util.Random;

// Set the DPI to make your smartwatch 1 inch square. Measure it on the screen
final int DPIofYourDeviceScreen = 128; // Josie's laptop's pixel density
//http://en.wikipedia.org/wiki/List_of_displays_by_pixel_density

//Do not change the following variables
String[] phrases; //contains all of the phrases
String[] suggestions; //contains all of the phrases
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





// --------------------- OUR GLOBAL VARIABLES ----------------------------------

float watchLeft; // lower bound of X
float watchRight; // upper bound of X
float watchTop; // lower bound of Y
float watchBottom; // upper bound of Y

float mouseOffsetX = 60;
float mouseOffsetY = 100;

int mode = 0;
int clickMode = 0;
float clickTime;
float maxCooldown = 500;
int charOffset = 0;

String currentLetter = "";













// ----------------------- CENTRAL FUNCTIONS -----------------------------------

//You can modify anything in here. This is just a basic implementation.
void setup()
{
  pixelDensity(1);
  
  
  
  watch = loadImage("watchhand3smaller.png");
  phrases = loadStrings("phrases2.txt"); //load the phrase set into memory 
  Collections.shuffle(Arrays.asList(phrases), new Random()); //randomize the order of the phrases with no seed
  //Collections.shuffle(Arrays.asList(phrases), new Random(100)); //randomize the order of the phrases with seed 100; same order every time, useful for testing
 
  orientation(LANDSCAPE); //can also be PORTRAIT - sets orientation on android device
  size(800, 800); //Sets the size of the app. You should modify this to your device's native size. Many phones today are 1080 wide by 1920 tall.
  textFont(createFont("Arial", 24)); //set the font to arial 24. Creating fonts is expensive, so make difference sizes once in setup, not draw
  noStroke(); //my code doesn't use any strokes
  
  //set finger as cursor. do not change the sizing.
  noCursor();
  mouseCursor = loadImage("finger.png"); //load finger image to use as cursor
  cursorHeight = DPIofYourDeviceScreen * (400.0/250.0); //scale finger cursor proportionally with DPI
  cursorWidth = cursorHeight * 0.6; 
  
  watchLeft = width / 2 - sizeOfInputArea / 2; // lower bound of X
  watchRight = watchLeft + sizeOfInputArea; // upper bound of X
  watchTop = height / 2 - sizeOfInputArea / 2; // lower bound of Y
  watchBottom = watchTop + sizeOfInputArea; // upper bound of Y
  
  
  
  
  
  
  
  
  
  loadWords();
  
  
  
  
  
  
  
  
}

//You can modify anything in here. This is just a basic implementation.
void draw()
{
  background(255); //clear background
  // drawWatch(); //draw watch background
  
  // draw watch screen
  fill(100);
  rect(width/2-sizeOfInputArea/2, height/2-sizeOfInputArea/2, sizeOfInputArea, sizeOfInputArea); //input area should be 1" by 1"

  // finish message
  if (finishTime!=0)
  {
    fill(128);
    textAlign(CENTER);
    text("Finished", 280, 150);
    cursor(ARROW);
    return;
  }

  // start message
  if (startTime==0 & !mousePressed)
  {
    fill(128);
    textAlign(CENTER);
    text("Click to start time!", 280, 150); //display this messsage until the user clicks!
  }

  // starting
  if (startTime==0 & mousePressed)
  {
    nextTrial(); //start the trials!
  }

  if (startTime!=0)
  {
    //feel free to change the size and position of the target/entered phrases and next button 
    textAlign(LEFT); //align the text left
    fill(128);
    text("Phrase " + (currTrialNum+1) + " of " + totalTrialNum, 70, 50); //draw the trial count
    fill(128);
    text("Target:   " + currentPhrase, 70, 100); //draw the target string
    text("Entered:  " + currentTyped + currentLetter +"|", 70, 140); //draw what the user has entered thus far 
    
    
    if (mode == 0)
      drawOverview();
    else
      drawButtons();
      
    if (clickMode > 0) {
      drawCooldown();
    }
    
  }
  
  
  
  //draw cursor with middle of the finger nail being the cursor point. do not change this.
  image(mouseCursor, mouseX+cursorWidth/2-cursorWidth/3, mouseY+cursorHeight/2-cursorHeight/5, cursorWidth, cursorHeight); //draw user cursor   
}

float buttonLeft(int col, float buttonPadding, float buttonWidth) {
  float x = watchLeft + buttonPadding;
  x += col * (buttonPadding + buttonWidth);
  return x;
}

float buttonTop(int row, float buttonPadding, float buttonHeight) {
  float y = watchTop + buttonPadding;
  y += row * (buttonPadding + buttonHeight);
  return y;
}

float buttonCenterX(int col, float buttonPadding, float buttonWidth) {
  float x = watchLeft + buttonPadding + buttonWidth / 2;
  x += col * (buttonPadding + buttonWidth);
  return x;
}

float buttonCenterY(int row, float buttonPadding, float buttonHeight) {
  float y = watchTop + buttonPadding + buttonHeight / 2;
  y += row * (buttonPadding + buttonHeight);
  return y;
}

char characterMap(int r, int c, int n) {
  int x = r * 9 + c * 3 + n;
  char output = (char) (97 + x);
  return output;
}

void drawOverview() {
  float buttonPadding = 4.0;
  
  float bigProportion = 2.0/3;
  int numCols = 3;
  
  float x = watchLeft + buttonPadding;
  float y = watchTop + buttonPadding;
  
  float bigHeight = (sizeOfInputArea - 3 * buttonPadding) * bigProportion;
  float bigWidth = sizeOfInputArea - 2 * buttonPadding;
  float buttonHeight = (sizeOfInputArea - 3 * buttonPadding) * (1 - bigProportion);
  float buttonWidth = (sizeOfInputArea - (numCols + 1) * buttonPadding) / numCols;
  
  pushMatrix();
  fill(240, 255, 255);
  rect(x, y, bigWidth, bigHeight);
  
  y += bigHeight + buttonPadding;
  for (int c = 0; c < numCols; c++) {
    if (c == 2) {
      fill(120, 240, 60);
    }
    
    rect(x, y, buttonWidth, buttonHeight);
    x += buttonWidth + buttonPadding;
  }
  popMatrix();
  
  pushMatrix();
  fill(70);
  textSize(18);
  textAlign(CENTER, CENTER);
  
  x = watchLeft + buttonPadding + bigWidth / 2;
  y = watchTop + buttonPadding + bigHeight / 2;
  text("alphabet", x, y);
  
  textSize(12);
  
  x = watchLeft + buttonPadding + buttonWidth / 2;
  y = watchTop + 2 * buttonPadding + bigHeight + buttonHeight / 2;
  text("space", x, y);
  
  x += buttonWidth + buttonPadding;
  text("back", x, y);
  
  textSize(9);
  fill(0);
  x += buttonWidth + buttonPadding;
  text("confirm", x, y);
  
  textSize(24);
  
  popMatrix();
}

void drawButtons() {
  float buttonPadding = 4.0;
  
  int numRows = 3;
  int numCols = 3;
  
  float buttonWidth = (sizeOfInputArea - (numCols + 1) * buttonPadding) / numCols;
  float buttonHeight = (sizeOfInputArea - (numRows + 1) * buttonPadding) / numRows;
  
  pushMatrix();
  fill(240, 255, 255);
  for (int c = 0; c < numCols; c++) {
    for (int r = 0; r < numRows; r++) {
      float x = buttonLeft(c, buttonPadding, buttonWidth);
      float y = buttonTop(r, buttonPadding, buttonWidth);
      rect(x, y, buttonWidth, buttonHeight);
    }
  }
  popMatrix();
  
  // text
  
  pushMatrix();
  fill(70);
  textSize(18);
  textAlign(CENTER, CENTER);
  
  for (int r = 0; r < numRows; r++){
    for (int c = 0; c < numCols; c++){
      String buttonText = "";
      for (int n = 0; n < 3; n++){
        if ((9 * r + 3 * c + n) == 26) break;
        buttonText += characterMap(r, c, n);
      }
      text(buttonText, buttonCenterX(c, buttonPadding, buttonHeight), buttonCenterY(r, buttonPadding, buttonWidth));
    }
  }
  
  textSize(24);
  
  popMatrix();
  
}

void drawCooldown() {
  float pad = 10;
  float barX = watchRight + pad;
  float barY = watchTop;
  float barWidth = 20;
  float barHeight = sizeOfInputArea;
  
  float timeSinceClick = millis() - clickTime;
  float timeRatio = 1 - timeSinceClick / maxCooldown;
  
  if (timeRatio < 0) {
    timeOut();
  }
  
  pushMatrix();
  fill(100, 50, 50);
  
  rect(barX, barY, barWidth, barHeight * timeRatio);
  
  popMatrix();
  
}











// ------------------------- MOUSE INPUT --------------------------------------

//my terrible implementation you can entirely replace
void mousePressed()
{
  
  if (startTime == 0) return;
  
  float buttonPadding = 4.0;
  int numRows = 3;
  int numCols = 3;
  
  if (mode == 0) {
    float bigProportion = 2.0/3;
    
    //float x = watchLeft + buttonPadding;
    //float y = watchTop + buttonPadding;
    
    float bigHeight = (sizeOfInputArea - 3 * buttonPadding) * bigProportion;
    float bigWidth = sizeOfInputArea - 2 * buttonPadding;
    float buttonHeight = (sizeOfInputArea - 3 * buttonPadding) * (1 - bigProportion);
    float buttonWidth = (sizeOfInputArea - (numCols + 1) * buttonPadding) / numCols;
    
    // rect(mouseX + mouseOffsetX, mouseY + mouseOffsetY, 10, 10);
    
    
    if (didMouseClick(watchLeft + buttonPadding, watchTop + buttonPadding, bigWidth, bigHeight)) {
      // alphabet
      mode = 1;
    } else if (didMouseClick(watchLeft + buttonPadding, watchTop + bigHeight + buttonPadding * 2, buttonWidth, buttonHeight)) {
      // space
      currentTyped += " ";
      printRecommendation();
    } else if (didMouseClick(watchLeft + buttonWidth + buttonPadding * 2, watchTop + bigHeight + buttonPadding * 2, buttonWidth, buttonHeight)) {
      // backspace
      backspace();
    } else if (didMouseClick(watchLeft + buttonWidth * 2 + buttonPadding * 3, watchTop + bigHeight + buttonPadding * 2, buttonWidth, buttonHeight)) {
      // submit
      nextTrial();
      currentLetter = "";
    }
    
    
  } else {
    float buttonWidth = (sizeOfInputArea - (numCols + 1) * buttonPadding) / numCols;
    float buttonHeight = (sizeOfInputArea - (numRows + 1) * buttonPadding) / numRows;
    
    if (didMouseClick(watchLeft, watchTop, sizeOfInputArea, sizeOfInputArea)) {
      float x = mouseX + mouseOffsetX;
      float y = mouseY + mouseOffsetY;
      
      int c = (int) ((x - watchLeft - buttonPadding / 2) / (buttonWidth + buttonPadding));
      int r = (int) ((y - watchTop - buttonPadding / 2) / (buttonHeight + buttonPadding));
      
      if (clickMode == 0) {
        clickMode = r * 3 + c + 1;
        currentLetter = Character.toString(characterMap(r, c, 0));
        clickTime = millis();
      } else {
        if (clickMode == r * 3 + c + 1) {
          charOffset += 1;
          currentLetter = (Character.toString(currentLetter.charAt(0) + 1));
          if ( ((clickMode == 9) && (charOffset == 2)) || (charOffset == 3) ) {
            charOffset = 0;
            currentLetter = Character.toString(characterMap(r, c, 0));
          }
        } else {
          // do nothing?
        }
      }
      
    }
    
  }
  
}







// --------------------------- DRAWING ----------------------------------------

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










// ------------------------ CONTROL FLOW ---------------------------------------

void nextTrial()
{
  if (currTrialNum >= totalTrialNum) //check to see if experiment is done
    return; //if so, just return

  if (startTime!=0 && finishTime==0) //in the middle of trials
  {
    System.out.println("==================");
    System.out.println("Phrase " + (currTrialNum+1) + " of " + totalTrialNum); //output
    System.out.println("Target phrase: " + currentPhrase); //output
    System.out.println("Phrase length: " + currentPhrase.length()); //output
    System.out.println("User typed: " + currentTyped); //output
    System.out.println("User typed length: " + currentTyped.length()); //output
    System.out.println("Number of errors: " + computeLevenshteinDistance(currentTyped.trim(), currentPhrase.trim())); //trim whitespace and compute errors
    System.out.println("Time taken on this trial: " + (millis()-lastTime)); //output
    System.out.println("Time taken since beginning: " + (millis()-startTime)); //output
    System.out.println("==================");
    lettersExpectedTotal+=currentPhrase.trim().length();
    lettersEnteredTotal+=currentTyped.trim().length();
    errorsTotal+=computeLevenshteinDistance(currentTyped.trim(), currentPhrase.trim());
  }

  //probably shouldn't need to modify any of this output / penalty code.
  if (currTrialNum == totalTrialNum-1) //check to see if experiment just finished
  {
    finishTime = millis();
    System.out.println("==================");
    System.out.println("Trials complete!"); //output
    System.out.println("Total time taken: " + (finishTime - startTime)); //output
    System.out.println("Total letters entered: " + lettersEnteredTotal); //output
    System.out.println("Total letters expected: " + lettersExpectedTotal); //output
    System.out.println("Total errors entered: " + errorsTotal); //output

    float wpm = (lettersEnteredTotal/5.0f)/((finishTime - startTime)/60000f); //FYI - 60K is number of milliseconds in minute
    float freebieErrors = lettersExpectedTotal*.05; //no penalty if errors are under 5% of chars
    float penalty = max(errorsTotal-freebieErrors, 0) * .5f;
    
    System.out.println("Raw WPM: " + wpm); //output
    System.out.println("Freebie errors: " + freebieErrors); //output
    System.out.println("Penalty: " + penalty);
    System.out.println("WPM w/ penalty: " + (wpm-penalty)); //yes, minus, becuase higher WPM is better
    System.out.println("==================");

    currTrialNum++; //increment by one so this mesage only appears once when all trials are done
    return;
  }

  if (startTime==0) //first trial starting now
  {
    System.out.println("Trials beginning! Starting timer..."); //output we're done
    startTime = millis(); //start the timer!
  } 
  else
    currTrialNum++; //increment trial number

  lastTime = millis(); //record the time of when this trial ended
  currentTyped = ""; //clear what is currently typed preparing for next trial
  printRecommendation();
  currentPhrase = phrases[currTrialNum]; // load the next phrase!
  //currentPhrase = "abc"; // uncomment this to override the test phrase (useful for debugging)
}








// ---------------------- HELPER FUNCTIONS ------------------------------------

//my terrible implementation you can entirely replace
boolean didMouseClickOLD(float x, float y, float w, float h) //simple function to do hit testing
{
  return (mouseX > x && mouseX<x+w && mouseY>y && mouseY<y+h); //check to see if it is in button bounds
}

boolean didMouseClick(float x, float y, float w, float h) //simple function to do hit testing
{
  return (mouseX > (x - mouseOffsetX) && mouseX < (x + w - mouseOffsetX) && mouseY > (y - mouseOffsetY) && mouseY < (y + h - mouseOffsetY)); //check to see if it is in button bounds
}

void backspace() {
  int l = currentTyped.length();
  if (l == 0) return;
  currentTyped = currentTyped.substring(0, l-1);
}

void timeOut() {
  clickMode = 0;
  currentTyped += currentLetter;
  currentLetter = "";
  mode = 0;
  charOffset = 0;
  
  printRecommendation();
}









//=========SHOULD NOT NEED TO TOUCH THIS METHOD AT ALL!==============
int computeLevenshteinDistance(String phrase1, String phrase2) //this computers error between two strings
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
