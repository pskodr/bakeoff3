import java.util.Arrays;
import java.util.Collections;
import java.util.Random;
import java.util.HashMap;
import java.util.ArrayList;

final int DPIofYourDeviceScreen = 150;

// ── phrase & trial state ────────────────────────────────────────────────────
String[] phrases;
int totalTrialNum = 3 + (int)random(3);
int currTrialNum  = 0;
float startTime   = 0, finishTime = 0, lastTime = 0;
float lettersEnteredTotal = 0, lettersExpectedTotal = 0, errorsTotal = 0;
String currentPhrase = "", currentTyped = "";

final float sizeOfInputArea = DPIofYourDeviceScreen * 1; // 1-inch square

// ── assets ──────────────────────────────────────────────────────────────────
PImage watch, mouseCursor;
float cursorHeight, cursorWidth;

// ── keyboard state ──────────────────────────────────────────────────────────
// Groups: 0=A-F, 1=G-L, 2=M-R+Y, 3=S-X+Z  (+ space)
String[][] groups = {
  {"a","b","c","d","e","f"},
  {"g","h","i","j","k","l"},
  {"m","n","o","p","q","r","y"},
  {"s","t","u","v","w","x","z"}
};
String[] groupLabels = {"A–F", "G–L", "M–R", "S–Z"};

int selectedGroup  = -1;  // -1 = showing group grid
int hoverCell      = -1;  // for visual feedback

// ── double-tap for space ─────────────────────────────────────────────────────
float lastTapTime = 0;
float lastTapX = 0, lastTapY = 0;
final float DOUBLE_TAP_MS   = 300;
final float DOUBLE_TAP_DIST = 60;

// ── suggestions ──────────────────────────────────────────────────────────────
final int NUM_SUGGESTIONS = 3;
String[] suggestions = new String[NUM_SUGGESTIONS];
HashMap<String,Integer> wordFreq = new HashMap<String,Integer>();
String[] wordList; // sorted by frequency

// ── colours (Processing color ints) ─────────────────────────────────────────
color COL_BG        = color(245, 244, 240);
color COL_PANEL     = color(255, 255, 255);
color COL_GROUP_A   = color(83, 74, 183);   // purple-600
color COL_GROUP_B   = color(15, 110, 86);   // teal-600
color COL_GROUP_C   = color(153, 60, 29);   // coral-600
color COL_GROUP_D   = color(24, 95, 165);   // blue-600
color COL_LETTER    = color(60, 52, 137);   // purple-800
color COL_SUGG      = color(99, 153, 34);   // green-600
color COL_SUGG_TXT  = color(39, 80, 10);    // green-800
color COL_BACK      = color(162, 45, 45);   // red-600
color COL_SPACE     = color(136, 135, 128); // gray-400
color COL_NEXT      = color(186, 117, 23);  // amber-600
color COL_TEXT_HI   = color(255, 255, 255);
color COL_TEXT_LO   = color(44, 44, 42);    // gray-900
color[] groupColors = {COL_GROUP_A, COL_GROUP_B, COL_GROUP_C, COL_GROUP_D};

// ── layout helpers ───────────────────────────────────────────────────────────
float ox, oy; // top-left of the 1" input area
float W, H;   // width/height of the area (both = sizeOfInputArea)

// Row split: top third = suggestions, bottom two-thirds = keyboard
float ROW_SUGG_H; // height of suggestion row
float ROW_KB_Y;   // y start of keyboard rows
float ROW_KB_H;   // height of keyboard portion

// Fonts
PFont fontBig, fontMed, fontSm;

// ── animation: flash when letter confirmed ────────────────────────────────
String flashChar = "";
float flashAlpha = 0;

void setup() {
  watch      = loadImage("watchhand3smaller.png");
  phrases    = loadStrings("phrases2.txt");
  Collections.shuffle(Arrays.asList(phrases), new Random());

  orientation(LANDSCAPE);
  size(800, 800);

  fontBig = createFont("Arial Bold", 20);
  fontMed = createFont("Arial",      15);
  fontSm  = createFont("Arial",      11);

  noStroke();

  noCursor();
  mouseCursor  = loadImage("finger.png");
  cursorHeight = DPIofYourDeviceScreen * (400.0/250.0);
  cursorWidth  = cursorHeight * 0.6;

  // Precompute layout coords
  ox = width/2  - sizeOfInputArea/2;
  oy = height/2 - sizeOfInputArea/2;
  W  = sizeOfInputArea;
  H  = sizeOfInputArea;

  ROW_SUGG_H = H * 0.28;
  ROW_KB_Y   = oy + ROW_SUGG_H;
  ROW_KB_H   = H  - ROW_SUGG_H;

  // Build word frequency from phrase list (run once)
  buildWordFrequency();
  updateSuggestions();
}

void draw() {
  background(COL_BG);
  drawWatch();

  // ── outer panel ──
  fill(COL_PANEL);
  rect(ox, oy, W, H, 8);

  if (finishTime != 0) {
    drawFinished();
    image(mouseCursor, mouseX+cursorWidth/2-cursorWidth/3,
                       mouseY+cursorHeight/2-cursorHeight/5,
                       cursorWidth, cursorHeight);
    return;
  }

  if (startTime == 0 && !mousePressed) {
    drawStartScreen();
    image(mouseCursor, mouseX+cursorWidth/2-cursorWidth/3,
                       mouseY+cursorHeight/2-cursorHeight/5,
                       cursorWidth, cursorHeight);
    return;
  }

  if (startTime == 0 && mousePressed) {
    nextTrial();
  }

  if (startTime != 0) {
    drawHUD();
    drawInputArea();
  }

  // Flash overlay
  if (flashAlpha > 0) {
    fill(255, 255, 200, flashAlpha);
    noStroke();
    rect(ox, oy, W, H, 8);
    textAlign(CENTER, CENTER);
    textFont(fontBig);
    fill(80, 60, 0, flashAlpha * 2);
    text(flashChar.equals(" ") ? "SPACE" : flashChar.toUpperCase(), ox+W/2, oy+H/2);
    flashAlpha = max(0, flashAlpha - 18);
  }

  image(mouseCursor, mouseX+cursorWidth/2-cursorWidth/3,
                     mouseY+cursorHeight/2-cursorHeight/5,
                     cursorWidth, cursorHeight);
}

// ── HUD (above the watch area) ──────────────────────────────────────────────
void drawHUD() {
  textFont(fontSm);
  fill(COL_TEXT_LO);
  textAlign(LEFT, TOP);
  text("Phrase " + (currTrialNum+1) + " / " + totalTrialNum, 30, 20);

  fill(50);
  textFont(fontMed);
  text("Target:  " + currentPhrase,              30, 40);
  text("Entered: " + currentTyped + "|",         30, 65);

  // NEXT button (outside 1" area)
  fill(COL_NEXT);
  rect(width-130, height-80, 110, 60, 6);
  fill(COL_TEXT_HI);
  textFont(fontMed);
  textAlign(CENTER, CENTER);
  text("NEXT ›", width-75, height-50);
}

// ── main input area ──────────────────────────────────────────────────────────
void drawInputArea() {
  // ── Row 0: suggestion strip ──────────────────────────────────────────────
  float sw = W / NUM_SUGGESTIONS;
  for (int i = 0; i < NUM_SUGGESTIONS; i++) {
    float sx = ox + i * sw;
    color bc = (i % 2 == 0) ? color(red(COL_SUGG)*0.9, green(COL_SUGG)*0.9, blue(COL_SUGG)*0.9) : COL_SUGG;
    fill(bc);
    if (i == 0) rect(sx, oy, sw, ROW_SUGG_H, 8, 0, 0, 0);
    else if (i == NUM_SUGGESTIONS-1) rect(sx, oy, sw, ROW_SUGG_H, 0, 8, 0, 0);
    else rect(sx, oy, sw, ROW_SUGG_H);

    // divider
    if (i < NUM_SUGGESTIONS-1) {
      fill(255, 40);
      rect(sx+sw-1, oy+4, 1, ROW_SUGG_H-8);
    }

    fill(COL_TEXT_HI);
    textFont(suggestions[i] != null && suggestions[i].length() > 7 ? fontSm : fontMed);
    textAlign(CENTER, CENTER);
    text(suggestions[i] != null ? suggestions[i] : "", sx+sw/2, oy+ROW_SUGG_H/2);
  }

  // ── Keyboard area: two rows beneath suggestions ──────────────────────────
  float kbH = ROW_KB_H;
  float rowH = kbH / 2;

  if (selectedGroup == -1) {
    // Show 4 group buttons (2×2) + backspace + space in bottom row
    // Top kb row: 4 group buttons in 2 columns × 2 rows
    for (int r = 0; r < 2; r++) {
      for (int c = 0; c < 2; c++) {
        int gi = r * 2 + c;
        float bx = ox + c * (W/2);
        float by = ROW_KB_Y + r * rowH;
        float bw = W/2, bh = rowH;

        color gc = groupColors[gi];
        // darken on hover
        if (hoverCell == gi) gc = darken(gc, 20);
        fill(gc);
        drawCell(bx, by, bw, bh, r, c);

        fill(COL_TEXT_HI);
        textFont(fontBig);
        textAlign(CENTER, CENTER);
        text(groupLabels[gi], bx+bw/2, by+bh/2);
      }
    }
  } else {
    // Show letters of chosen group (up to 7 letters, 2 cols × rows)
    String[] letters = groups[selectedGroup];
    int cols = 2;
    int rows = (int)Math.ceil(letters.length / (float)cols);

    // Reserve strip first, then divide remaining space among letter rows
    float stripH = rowH * 0.6;
    float stripY = oy + H - stripH;
    float lettersAreaH = kbH - stripH;
    float cellW = W / cols;
    float cellH = lettersAreaH / rows;

    for (int i = 0; i < letters.length; i++) {
      int r = i / cols, c = i % cols;
      float bx = ox + c * cellW;
      float by = ROW_KB_Y + r * cellH;

      color gc = groupColors[selectedGroup];
      float bright = map(i, 0, letters.length-1, 0, 30);
      gc = lighten(gc, (int)bright);
      if (hoverCell == i) gc = darken(gc, 15);
      fill(gc);
      drawCell(bx, by, cellW, cellH, r, c);

      fill(COL_TEXT_HI);
      textFont(fontBig);
      textAlign(CENTER, CENTER);
      text(letters[i].toUpperCase(), bx+cellW/2, by+cellH/2);
    }

    // Bottom strip: Back (left) + Delete (right)
    fill(COL_BACK);
    rect(ox, stripY, W/2, stripH, 0, 0, 8, 0);
    fill(COL_TEXT_HI);
    textFont(fontMed);
    textAlign(CENTER, CENTER);
    text("‹ back", ox+W/4, stripY+stripH/2);

    fill(COL_SPACE);
    rect(ox+W/2, stripY, W/2, stripH, 0, 0, 0, 8);
    fill(COL_TEXT_HI);
    text("⌫ del", ox+W*3/4, stripY+stripH/2);
  }
}

// ── helper: draw cell with correct corner radius for position ────────────────
void drawCell(float bx, float by, float bw, float bh, int row, int col) {
  // We manually handle corners to keep inner borders flush
  rect(bx, by, bw, bh);
}

// ── start / finish screens ───────────────────────────────────────────────────
void drawStartScreen() {
  fill(COL_PANEL);
  rect(ox, oy, W, H, 8);
  fill(COL_GROUP_A);
  textFont(fontMed);
  textAlign(CENTER, CENTER);
  text("Tap to start", ox+W/2, oy+H/2);
}

void drawFinished() {
  fill(COL_PANEL);
  rect(ox, oy, W, H, 8);
  fill(COL_GROUP_B);
  textFont(fontBig);
  textAlign(CENTER, CENTER);
  text("Done!", ox+W/2, oy+H/2);
  cursor(ARROW);
}

// ── touch / mouse ────────────────────────────────────────────────────────────
boolean didClick(float x, float y, float w, float h) {
  return mouseX>x && mouseX<x+w && mouseY>y && mouseY<y+h;
}

void mousePressed() {
  if (startTime == 0 || finishTime != 0) return;

  // ── double-tap → space ────────────────────────────────────────────────────
  float now = millis();
  float dx = mouseX - lastTapX, dy = mouseY - lastTapY;
  float dist = sqrt(dx*dx + dy*dy);
  if (now - lastTapTime < DOUBLE_TAP_MS && dist < DOUBLE_TAP_DIST) {
    typeChar(" ");
    lastTapTime = 0;
    return;
  }
  lastTapTime = now;
  lastTapX = mouseX;
  lastTapY = mouseY;

  // ── NEXT button ───────────────────────────────────────────────────────────
  if (didClick(width-130, height-80, 110, 60)) {
    nextTrial();
    return;
  }

  // ── suggestion strip ──────────────────────────────────────────────────────
  float sw = W / NUM_SUGGESTIONS;
  for (int i = 0; i < NUM_SUGGESTIONS; i++) {
    if (didClick(ox + i*sw, oy, sw, ROW_SUGG_H)) {
      if (suggestions[i] != null && suggestions[i].length() > 0) {
        // Insert suggestion: strip current partial word and replace
        String typed = currentTyped;
        int lastSpace = typed.lastIndexOf(' ');
        String base = (lastSpace == -1) ? "" : typed.substring(0, lastSpace+1);
        currentTyped = base + suggestions[i] + " ";
        updateSuggestions();
        flashChar = suggestions[i];
        flashAlpha = 120;
      }
      return;
    }
  }

  float kbH = ROW_KB_H;
  float rowH = kbH / 2;

  if (selectedGroup == -1) {
    // ── group grid ────────────────────────────────────────────────────────
    for (int r = 0; r < 2; r++) {
      for (int c = 0; c < 2; c++) {
        int gi = r*2+c;
        if (didClick(ox+c*(W/2), ROW_KB_Y+r*rowH, W/2, rowH)) {
          selectedGroup = gi;
          return;
        }
      }
    }
  } else {
    // ── letter grid ──────────────────────────────────────────────────────
    String[] letters = groups[selectedGroup];
    int cols = 2;
    int rows = (int)Math.ceil(letters.length / (float)cols);
    float stripH = rowH * 0.6;
    float stripY = oy + H - stripH;
    float cellW = W / cols;
    float cellH = (ROW_KB_H - stripH) / rows;

    for (int i = 0; i < letters.length; i++) {
      int r = i/cols, c = i%cols;
      if (didClick(ox+c*cellW, ROW_KB_Y+r*cellH, cellW, cellH)) {
        typeChar(letters[i]);
        selectedGroup = -1;
        return;
      }
    }

    // Back button
    if (didClick(ox, stripY, W/2, stripH)) {
      selectedGroup = -1;
      return;
    }
    // Delete button
    if (didClick(ox+W/2, stripY, W/2, stripH)) {
      if (currentTyped.length() > 0)
        currentTyped = currentTyped.substring(0, currentTyped.length()-1);
      updateSuggestions();
      selectedGroup = -1;
      return;
    }
  }
}

// ── type a character ─────────────────────────────────────────────────────────
void typeChar(String ch) {
  currentTyped += ch;
  flashChar  = ch;
  flashAlpha = 160;
  updateSuggestions();
}

// ── suggestion engine ────────────────────────────────────────────────────────
void buildWordFrequency() {
  for (String p : phrases) {
    for (String w : p.toLowerCase().split("\\s+")) {
      w = w.replaceAll("[^a-z]", "");
      if (w.length() > 0)
        wordFreq.put(w, wordFreq.containsKey(w) ? wordFreq.get(w)+1 : 1);
    }
  }
  // Sort by frequency descending
  ArrayList<String> keys = new ArrayList<String>(wordFreq.keySet());
  Collections.sort(keys, (a, b) -> wordFreq.get(b) - wordFreq.get(a));
  wordList = keys.toArray(new String[0]);
}

void updateSuggestions() {
  String typed = currentTyped.toLowerCase();
  int lastSpace = typed.lastIndexOf(' ');
  String prefix = (lastSpace == -1) ? typed : typed.substring(lastSpace+1);

  for (int i = 0; i < NUM_SUGGESTIONS; i++) suggestions[i] = "";

  int found = 0;
  if (wordList == null) return;

  // Exact-prefix matches, ordered by frequency
  for (String w : wordList) {
    if (found >= NUM_SUGGESTIONS) break;
    if (prefix.length() == 0 || w.startsWith(prefix)) {
      // Don't suggest the word already fully typed
      if (!w.equals(prefix))
        suggestions[found++] = w;
    }
  }
}

// ── colour utilities ─────────────────────────────────────────────────────────
color darken(color c, int amt) {
  return color(max(0,red(c)-amt), max(0,green(c)-amt), max(0,blue(c)-amt));
}
color lighten(color c, int amt) {
  return color(min(255,red(c)+amt), min(255,green(c)+amt), min(255,blue(c)+amt));
}

// ── watch background ──────────────────────────────────────────────────────────
void drawWatch() {
  float watchscale = DPIofYourDeviceScreen/138.0;
  pushMatrix();
  translate(width/2, height/2);
  scale(watchscale);
  imageMode(CENTER);
  image(watch, 0, 0);
  popMatrix();
}

// ── nextTrial (unchanged logic from original) ─────────────────────────────────
void nextTrial() {
  if (currTrialNum >= totalTrialNum) return;

  if (startTime != 0 && finishTime == 0) {
    System.out.println("==================");
    System.out.println("Phrase " + (currTrialNum+1) + " of " + totalTrialNum);
    System.out.println("Target phrase: "      + currentPhrase);
    System.out.println("Phrase length: "      + currentPhrase.length());
    System.out.println("User typed: "         + currentTyped);
    System.out.println("User typed length: "  + currentTyped.length());
    System.out.println("Number of errors: "   + computeLevenshteinDistance(currentTyped.trim(), currentPhrase.trim()));
    System.out.println("Time taken on this trial: "    + (millis()-lastTime));
    System.out.println("Time taken since beginning: "  + (millis()-startTime));
    System.out.println("==================");
    lettersExpectedTotal += currentPhrase.trim().length();
    lettersEnteredTotal  += currentTyped.trim().length();
    errorsTotal          += computeLevenshteinDistance(currentTyped.trim(), currentPhrase.trim());
  }

  if (currTrialNum == totalTrialNum-1) {
    finishTime = millis();
    System.out.println("==================");
    System.out.println("Trials complete!");
    System.out.println("Total time taken: "        + (finishTime-startTime));
    System.out.println("Total letters entered: "   + lettersEnteredTotal);
    System.out.println("Total letters expected: "  + lettersExpectedTotal);
    System.out.println("Total errors entered: "    + errorsTotal);
    float wpm          = (lettersEnteredTotal/5.0f)/((finishTime-startTime)/60000f);
    float freebieErrors= lettersExpectedTotal*.05f;
    float penalty      = max(errorsTotal-freebieErrors, 0)*.5f;
    System.out.println("Raw WPM: "         + wpm);
    System.out.println("Freebie errors: "  + freebieErrors);
    System.out.println("Penalty: "         + penalty);
    System.out.println("WPM w/ penalty: "  + (wpm-penalty));
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
  selectedGroup = -1;
  updateSuggestions();
}

// ── Levenshtein (unchanged) ───────────────────────────────────────────────────
int computeLevenshteinDistance(String p1, String p2) {
  int[][] d = new int[p1.length()+1][p2.length()+1];
  for (int i=0;i<=p1.length();i++) d[i][0]=i;
  for (int j=1;j<=p2.length();j++) d[0][j]=j;
  for (int i=1;i<=p1.length();i++)
    for (int j=1;j<=p2.length();j++)
      d[i][j]=min(min(d[i-1][j]+1,d[i][j-1]+1),
                  d[i-1][j-1]+((p1.charAt(i-1)==p2.charAt(j-1))?0:1));
  return d[p1.length()][p2.length()];
}
