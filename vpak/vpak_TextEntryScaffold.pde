import java.util.Arrays;
import java.util.Collections;
import java.util.Random;

// Set the DPI to make your smartwatch 1 inch square. Measure it on the screen
final int DPIofYourDeviceScreen = 100; //you will need to look up the DPI or PPI of your device to make sure you get the right scale!!
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
float buttonWidth = sizeOfInputArea/2; //Button width
float buttonHeight = sizeOfInputArea/3; // Button height
float miscButtonHeight = sizeOfInputArea/2;
PImage watch;
PImage mouseCursor;
float cursorHeight;
float cursorWidth;


//Implementation variables
String alphabet = "abcdefghijklmnopqrstuvwxyz";
//Phases are the following:
//- Pre-game start (unstarted)
//- Section Select (section)
//- Letter AE (letterAE)
//- Letter FJ (letterFJ)
//- Letter KO (letterKO)
//- Letter PT (letterPT)
//- Letter UZ (letterUZ)
//- Space/Delete (misc) = space / delete
String phase = "unstarted";

//You can modify anything in here. This is just a basic implementation.
void setup()
{
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
}

//You can modify anything in here. This is just a basic implementation.
void draw()
{
  background(255); //clear background
  drawWatch(); //draw watch background
  fill(100);
  rect(width/2-sizeOfInputArea/2, height/2-sizeOfInputArea/2, sizeOfInputArea, sizeOfInputArea); //input area should be 1" by 1"

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
    text("Click to start time!", 280, 150); //display this messsage until the user clicks!
  }

  if (startTime==0 & mousePressed)
  {
    phase = "section";
    nextTrial(); //start the trials!
  }

  if (startTime!=0)
  {
    //feel free to change the size and position of the target/entered phrases and next button 
    textSize(24);
    textAlign(LEFT); //align the text left
    fill(128);
    text("Phrase " + (currTrialNum+1) + " of " + totalTrialNum, 70, 50); //draw the trial count
    fill(128);
    text("Target:   " + currentPhrase, 70, 100); //draw the target string
    text("Entered:  " + currentTyped +"|", 70, 140); //draw what the user has entered thus far 

    //Draw buttons for non-misc
    float top;
    float left;
    int countButtonIndex = 0;
    if (phase != "misc") {
      for (int i = 0; i < 3; i++) {
        top = (height/2-buttonHeight*1.5) + (buttonHeight*i);
        for (int j = 0; j < 2; j++) {
          left = (width/2-buttonWidth) + (buttonWidth * j);
          fill(255);
          stroke(0);
          strokeWeight(3);
          rect(left, top, buttonWidth, buttonHeight);
          drawLabel(countButtonIndex, left, top);
          countButtonIndex += 1;
        }
      } 
    // draw buttons for misc
    } else {
        left = (width/2-buttonWidth);
        for (int i = 0; i < 2; i++) {
          top = (height/2-buttonHeight*1.5) + (miscButtonHeight*i);
          fill(255);
          stroke(0);
          strokeWeight(3);
          rect(left, top, buttonWidth*2, miscButtonHeight);
          drawLabel(countButtonIndex, left, top);
          countButtonIndex += 1;
        }
      }
    }
  //draw cursor with middle of the finger nail being the cursor point. do not change this.
  image(mouseCursor, mouseX+cursorWidth/2-cursorWidth/3, mouseY+cursorHeight/2-cursorHeight/5, cursorWidth, cursorHeight); //draw user cursor   
}

// Label buttons:
void drawLabel(int buttonIndex, float left, float top) {
  fill(0);
  textSize(13.5);
  textAlign(CENTER);
  float textX = left+buttonWidth/2;
  float textY = top+buttonHeight/2;
  if (phase == "section") {
    String[] sectionLabels = {"A-E", "F-J", "K-O", "P-T", "U-Z", "Spc/Del"};
    text(sectionLabels[buttonIndex], textX, textY);
  } else if (phase == "misc") {
    String[] miscLabels = {"Space", "Delete"};
    textX = left + sizeOfInputArea/2;
    textY = top + miscButtonHeight/2;
    text(miscLabels[buttonIndex], textX, textY);
  } else {
    textSize(20);
    char letter = getLetter(buttonIndex);
    text(letter, textX, textY);
  }
}

// get letter at button to type into current phrase
char getLetter(int buttonIndex) {
  int offset = 0;
  if (phase == "letterFJ") {
    offset = 5;
  } else if (phase == "letterKO") {
    offset = 10;
  } else if (phase == "letterPT") {
    offset = 15;
  } else if (phase == "letterUZ") {
    offset = 20;
  }
  return alphabet.charAt(buttonIndex+offset);
}

//get button index of pressed button (0-5)
int getButtonIndex() 
{
  float buttonWidth = sizeOfInputArea/2;
  float buttonHeight = sizeOfInputArea/3;
  if (phase != "misc") {
    if ((width/2 - buttonWidth < mouseX && mouseX < width/2) &&
        (height/2-buttonHeight*1.5 < mouseY && mouseY < height/2-buttonHeight*1.5 + buttonHeight)) {
      return 0; // top left button
    } else if ((width/2 < mouseX && mouseX < width/2 + buttonWidth) &&
               (height/2-buttonHeight*1.5 < mouseY && mouseY < height/2-buttonHeight*1.5 + buttonHeight)) {
      return 1; // top right button
    } else if ((width/2 - buttonWidth < mouseX && mouseX < width/2) &&
               (height/2-buttonHeight*0.5 < mouseY && mouseY < height/2-buttonHeight*0.5 + buttonHeight)) {
      return 2; // middle left button
    } else if ((width/2 < mouseX && mouseX < width/2 + buttonWidth) &&
               (height/2-buttonHeight*0.5 < mouseY && mouseY < height/2-buttonHeight*0.5 + buttonHeight)) {
      return 3; // middle right button
    } else if ((width/2 - buttonWidth < mouseX && mouseX < width/2) &&
               (height/2+buttonHeight*0.5 < mouseY && mouseY < height/2+buttonHeight*0.5 + buttonHeight)) {
      return 4; // bottom left button
    } else if ((width/2 < mouseX && mouseX < width/2 + buttonWidth) &&
               (height/2+buttonHeight*0.5 < mouseY && mouseY < height/2+buttonHeight*0.5 + buttonHeight)) {
      return 5; // bottom right button
    }
  } else {
    if ((width/2 - buttonWidth < mouseX && mouseX < width/2 + buttonWidth) &&
        (height/2-buttonHeight*1.5 < mouseY && mouseY < height/2-buttonHeight*1.5 + miscButtonHeight)) {
      return 0; // space
    } else if ((width/2 - buttonWidth < mouseX && mouseX < width/2 + buttonWidth) &&
               (height/2-buttonHeight*1.5 + miscButtonHeight < mouseY && mouseY < height/2-buttonHeight*1.5 + 2*miscButtonHeight)) {
      return 1; // delete
    }
  }
  return 6;
}
  

// mouse press to control phases
void mousePressed()
{
  // get index of button:
  int buttonIndex = getButtonIndex();
  if (phase == "section") {
    if (buttonIndex == 0) {
      phase = "letterAE";
    } else if (buttonIndex == 1) {
      phase = "letterFJ";
    } else if (buttonIndex == 2) {
      phase = "letterKO";
    } else if (buttonIndex == 3) {
      phase = "letterPT";
    } else if (buttonIndex == 4) {
      phase = "letterUZ";
    } else if (buttonIndex == 5) {
      phase = "misc";
    }
  // if in misc phase, add space or delete character
  } else if (phase == "misc") {
    if (buttonIndex == 0) {
      currentTyped += " ";
    } else if (buttonIndex == 1) {
      if (currentTyped.length() > 0) {
        currentTyped = currentTyped.substring(0, currentTyped.length()-1);
      }
    }
    phase = "section";
  // Type character
  } else {
    char letter = getLetter(buttonIndex);
    currentTyped += letter;
    phase = "section";
  }
}


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
  currentPhrase = phrases[currTrialNum]; // load the next phrase!
  //currentPhrase = "abc"; // uncomment this to override the test phrase (useful for debugging)
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
