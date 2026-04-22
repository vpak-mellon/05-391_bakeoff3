import java.util.Arrays;

String[] wordList;
long[] wordFrequencies;
int numStored = 15000;

void loadWords() {
  String fname = "ngrams/count_1w.txt";
  String[] fcontents = loadStrings(fname);
  wordList = new String[numStored];
  wordFrequencies = new long[numStored];
  
  for (int i = 0; i < numStored; i ++) {
    String line = fcontents[i];
    int tabIndex = line.indexOf("\t");
    String word = line.substring(0, tabIndex).toLowerCase();
    long freq = Long.parseLong(line.substring(tabIndex + 1));
    wordList[i] = word;
    wordFrequencies[i] = freq;
  }
  
  sortWords();
}



void sortWordsHelper(int start, int end) {
  // QUICKSORT
  // as given by Michael Sambol
  
  if (end - start < 2) return;
  if (end - start == 2) {
    if (wordList[start].compareTo(wordList[start + 1]) > 0)
      swaps(start, start + 1);
    return;
  }
  
  // choose a pivot
  int ip = start; // pivot index
  String pivotValue = wordList[ip];
  
  // move pivot to the end
  swaps(ip, end - 1);
  ip = end - 1;
  
  // look for item from left larger than pivot
  // and item from right smaller than pivot
  // then swap them
  int il = start; // left index
  int ir = end - 2; // right index
  boolean l = false;
  boolean r = false;
  while (il < ir) {
    if (!l) {
      if (wordList[il].compareTo(pivotValue) > 0)
        l = true;
      else
        il++;
    } else if (!r) {
      if (wordList[ir].compareTo(pivotValue) < 0)
        r = true;
      else
        ir--;
    } else {
      swaps(il, ir);
      l = false;
      r = false;
    }
  }
  if (wordList[il].compareTo(wordList[ip]) > 0) {
    swaps(il, ip);
    
    // recursion
    sortWordsHelper(start, il);
    sortWordsHelper(il + 1, end);
  } else {
    sortWordsHelper(start, end - 1);
  }
  
  
  
}

void sortWords() {
  // println("Starting.");
  sortWordsHelper(0, numStored);
  //for (int i = 0; i < 100; i ++) {
  //  print(wordList[i]);
  //  print(" ----- ");
  //  println(wordFrequencies[i]);
  //}
}

float similarityScore(String input, String word) {
  float score = 1.0;
  float distanceRatio = 0.8;
  float typoDistanceRatio = 0.3;
  float typoScale = 0.01;
  
  int iLen = input.length();
  int wLen = word.length();
  int distance = computeLevenshteinDistance(input, word);
  
  if ((iLen <= wLen) && input.equals(word.substring(0, iLen))) {
    score *= Math.pow(distanceRatio, (wLen - iLen));
  } else {
    score *= typoScale;
    score *= Math.pow(typoDistanceRatio, distance);
  }
  return score;
}

//long wordFrequency(String word) {
//  return 1;
//}

int matchScore(String input, String word, int index) {
  float score = 0.0001;
  score = score * wordFrequencies[index];
  score = score * similarityScore(input, word);
  
  
  return (int) score;
}

String[] topChoices(String input, int n) {
  String[] bestWords = new String[n];
  int[] bestScores = new int[n];
  
  for (int i = 0; i < n; i++) {
    bestWords[i] = "";
  }
  
  for (int i = 0; i < numStored; i++) {
    String word = wordList[i];
    if (input.equals(word)) continue;
    int score = matchScore(input, word, i);
    int j = n;
    while (j > 0 && (score > bestScores[j - 1])) {
      j--;
    }
    int temp1 = score;
    int temp2;
    String tempw1 = word;
    String tempw2;
    for (int k = j; k < n; k++) {
      temp2 = bestScores[k];
      tempw2 = bestWords[k];
      bestScores[k] = temp1;
      bestWords[k] = tempw1;
      temp1 = temp2;
      tempw1 = tempw2;
    }
  }
  
  return bestWords;
}

void printRecommendation() {
  int n = 5;
  String input = "o";
  
  int si = currentTyped.lastIndexOf(" ");
  if (si < 0) {
    input = currentTyped;
  } else {
    input = currentTyped.substring(si + 1);
  }
  
  
  
  String[] a = topChoices(input, 5);
  for (int i = 0; i < n; i++) {
    print(i);
    print(": ");
    println(a[i]);
  }
  println("--------");
  
  //int b = weightedLevenshteinDistance(input, a[0]);
  //println(b);
  //println("//");
}














// HELPER FUNCTIONS


void swapStringsInArray(String[] arr, int i1, int i2) {
  String temp = arr[i1];
  arr[i1] = arr[i2];
  arr[i2] = temp;
}

void swapLongsInArray(long[] arr, int i1, int i2) {
  Long temp = arr[i1];
  arr[i1] = arr[i2];
  arr[i2] = temp;
}

void swaps(int i1, int i2) {
  swapStringsInArray(wordList, i1, i2);
  swapLongsInArray(wordFrequencies, i1, i2);
}

//int weightedLevenshteinDistance(String phrase1, String phrase2)
//{
//  int[][] distance = new int[phrase1.length() + 1][phrase2.length() + 1];

//  for (int i = 0; i <= phrase1.length(); i++)
//    distance[i][0] = i;
//  for (int j = 1; j <= phrase2.length(); j++)
//    distance[0][j] = j;

//  for (int i = 1; i <= phrase1.length(); i++)
//    for (int j = 1; j <= phrase2.length(); j++)
//      distance[i][j] = min(min(distance[i - 1][j] + 1, distance[i][j - 1] + 1), distance[i - 1][j - 1] + ((phrase1.charAt(i - 1) == phrase2.charAt(j - 1)) ? 0 : 1));
      
  
//  print("  ");
//  for (int j = 1; j <= phrase2.length(); j++) {
//    print(phrase2.substring(j - 1, j));
//    print(" ");
//  }
//  println();
//  for (int i = 1; i <= phrase1.length(); i++) {
//    print(phrase1.substring(i - 1, i));
//    print(" ");
//    for (int j = 1; j <= phrase2.length(); j++) {
//      print(distance[i][j]);
//      print(" ");
//    }
//    println();
//  }

//  return distance[phrase1.length()][phrase2.length()];
//}
