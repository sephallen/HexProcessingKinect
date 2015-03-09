// Built UponKinect Physics Example by Amnon Owed (15/09/12)
// marked line that changes gravity speed- A Rhys
// Twitter4J Twitter streaming API added

// import libraries
import java.util.*; // Processing 2+ doesn't import Java libraries by default
import processing.opengl.*; // opengl
import blobDetection.*; // blobs
import toxi.geom.*; // toxiclibs shapes and vectors
import toxi.processing.*; // toxiclibs display
import pbox2d.*; // shiffman's jbox2d helper library
import org.jbox2d.collision.shapes.*; // jbox2d
import org.jbox2d.common.*; // jbox2d
import org.jbox2d.dynamics.*; // jbox2d

//open kinect
import org.openkinect.*;
import org.openkinect.processing.*;
// Showing how we can farm all the kinect stuff out to a separate class
KinectTracker tracker;
// Kinect Library object
Kinect kinect;

// declare BlobDetection object
BlobDetection theBlobDetection;

// ToxiclibsSupport for displaying polygons
ToxiclibsSupport gfx;

// declare custom PolygonBlob object (see class for more info)
PolygonBlob poly;

// PImage to hold incoming imagery and smaller one for blob detection
PImage cam, blobs;
PImage logo;

// the kinect's dimensions to be used later on for calculations
int kinectWidth = 640;
int kinectHeight = 480;
int kAngle;

// to center and rescale from 640x480 to higher custom resolutions
float reScale;

// background and blob color
color bgColor, blobColor;
color col;

// three color palettes (artifact from me storing many interesting color palettes as strings in an external data file ;-)
//String[] palettes = {
//  "-13415076,-12209507,-1062580,-1934785,-2139575,-12942718" //Hex colour palette
//};

Integer[] colorPalette = {#334D5C, #45B29D, #EFC94C, #E27A3F, #DF5A49, #3A8282};

// the main PBox2D object in which all the physics-based stuff is happening
PBox2D box2d;

// list to hold all the custom shapes (circles, polygons)
ArrayList<CustomShape> polygons = new ArrayList<CustomShape>();

//Twitter4J API settings
///////////////////////////// Config your setup here! ////////////////////////////
// This is where you enter your Oauth info
static String OAuthConsumerKey = "";
static String OAuthConsumerSecret = "";
// This is where you enter your Access Token info
static String AccessToken = "";
static String AccessTokenSecret = "";

// if you enter keywords here it will filter, otherwise it will sample
String keywords[] = {
  "#hexpicam" //strings to search Twitter for
};
///////////////////////////// End Variable Config ////////////////////////////

TwitterStream twitter = new TwitterStreamFactory().getInstance();
PImage img;
boolean imageLoaded;

void setup() {
  // it's possible to customize this, for example 1920x1080
  size(1024, 768, OPENGL);
  
  logo = loadImage("logo.png");
  
  // open kinecy
  kinect = new Kinect(this);
  tracker = new KinectTracker();

    reScale = (float) width / kinectWidth;

    // create a smaller blob image for speed and efficiency
    blobs = createImage(kinectWidth/3, kinectHeight/3, RGB);

    // initialize blob detection object to the blob image dimensions
    theBlobDetection = new BlobDetection(blobs.width, blobs.height);
    theBlobDetection.setThreshold(0.2);

    // initialize ToxiclibsSupport object
    gfx = new ToxiclibsSupport(this);

    // setup box2d, create world, set gravity
    box2d = new PBox2D(this);
    box2d.createWorld();
// second number here is gravity speed -30 faster than -10
    box2d.setGravity(0, -20);

    // set random colors (background, blob)
    setRandomColors(1);
  
  // Connect to Twitter
  connectTwitter();
  twitter.addListener(listener);
  if (keywords.length==0) twitter.sample();
  else twitter.filter(new FilterQuery().track(keywords));
}

void draw() {

  background(bgColor);
  image(logo, 0,0,width/6,height/6);
  
  // set background color to first color from palette
  bgColor = colorPalette[0];
  
  // set blob color to second color from palette
  blobColor = colorPalette[1];

  // open kinect
  // Run the tracking analysis
  tracker.track();
  // Show the image
  tracker.display();

//  // put the image into a PImage
  cam = tracker.display;

  // copy the image into the smaller blob image
  blobs.copy(cam, 0, 0, cam.width, cam.height, 0, 0, blobs.width, blobs.height);

  // blur the blob image
  blobs.filter(BLUR, 1);

  // detect the blobs
  theBlobDetection.computeBlobs(blobs.pixels);

  // initialize a new polygon

  poly = new PolygonBlob();
  // create the polygon from the blobs (custom functionality, see class)

  poly.createPolygon();
  // create the box2d body from the polygon

  poly.createBody();
  // update and draw everything (see method)

  updateAndDrawBox2D();
  // destroy the person's body (important!)

  poly.destroyBody();
  
  // display the Twitter image in bottom left corner
  if (imageLoaded) {
    image(img,0,480-height/6,width/6,height/6);
//    Collections.shuffle(Arrays.asList(colorPalette));
  }
//  println(colorPalette);

}

// moving the kinect and changing threshold
void keyPressed() {
  int t = tracker.getThreshold();
  if (key == CODED) {
    if (keyCode == LEFT) {
      t+=5;
      tracker.setThreshold(t);
    } 
    if (keyCode == RIGHT) {
      t-=5;
      tracker.setThreshold(t);
    }
    if (keyCode == UP) {
      kAngle++;
    } 
    if (keyCode == DOWN) {
      kAngle--;
    }
    kAngle = constrain(kAngle, 0, 30);
    kinect.tilt(kAngle);
  }
}

void stop() {
  tracker.quit();
  super.stop();
}

void updateAndDrawBox2D() {

  // if frameRate is sufficient, add a polygon and a circle with a random radius
  if (frameRate > 29) {
    polygons.add(new CustomShape(kinectWidth/2, -50, -1));
    polygons.add(new CustomShape(kinectWidth/2, -50, random(2.5, 20)));
  }

  // take one step in the box2d physics world
  box2d.step();

  // center and reScale from Kinect to custom dimensions
  translate(0, (height-kinectHeight*reScale)/2);
  scale(reScale);

  // display the person's polygon  
  noStroke();
  fill(blobColor);
  gfx.polygon2D(poly);

  // display all the shapes (circles, polygons)
  // go backwards to allow removal of shapes
  for (int i=polygons.size()-1; i>=0; i--) {

    CustomShape cs = polygons.get(i);

    // if the shape is off-screen remove it (see class for more info)
    if (cs.done()) {
      polygons.remove(i);
    // otherwise update (keep shape outside person) and display (circle or polygon)
    } else {
      cs.update();
      cs.display();
    }
  }
}

// sets the colors every nth frame

void setRandomColors(int nthFrame) {

    // turn a palette into a series of strings
//    String[] paletteStrings = split(palettes[int(random(palettes.length))], ",");

    // turn strings into colors
//    colorPalette = new color[paletteStrings.length];

//    for (int i=0; i<paletteStrings.length; i++) {
//      colorPalette[i] = int(paletteStrings[i]);

      // set background color to first color from palette
//      bgColor = colorPalette[0];
  
      // set blob color to second color from palette
//      blobColor = colorPalette[1];
  }

// returns a random color from the palette (excluding first aka background color)
color getRandomColor() {
  return colorPalette[int(random(2, colorPalette.length))];
}

// Twitter4J
// Initial connection
void connectTwitter() {
  twitter.setOAuthConsumer(OAuthConsumerKey, OAuthConsumerSecret);
  AccessToken accessToken = loadAccessToken();
  twitter.setOAuthAccessToken(accessToken);
}

// Loading up the access token
private static AccessToken loadAccessToken() {
  return new AccessToken(AccessToken, AccessTokenSecret);
}

// This listens for new tweet
StatusListener listener = new StatusListener() {
  public void onStatus(Status status) {

//    println("@" + status.getUser().getScreenName() + " - " + status.getText());

    String imgUrl = null;
    String imgPage = null;

    // Checks for images posted using twitter API

    if (status.getMediaEntities() != null) {
      imgUrl= status.getMediaEntities()[0].getMediaURL().toString();
    }
    // Checks for images posted using other APIs

    else {
      if (status.getURLEntities().length > 0) {
        if (status.getURLEntities()[0].getExpandedURL() != null) {
          imgPage = status.getURLEntities()[0].getExpandedURL().toString();
        }
        else {
          if (status.getURLEntities()[0].getDisplayURL() != null) {
            imgPage = status.getURLEntities()[0].getDisplayURL().toString();
          }
        }
      }

      if (imgPage != null) imgUrl  = parseTwitterImg(imgPage);
    }

    if (imgUrl != null) {

      println("found image: " + imgUrl);

      // hacks to make image load correctly

      if (imgUrl.startsWith("//")){
        println("s3 weirdness");
        imgUrl = "http:" + imgUrl;
      }
      if (!imgUrl.endsWith(".jpg")) {
        byte[] imgBytes = loadBytes(imgUrl);
        saveBytes("tempImage.jpg", imgBytes);
        imgUrl = "tempImage.jpg";
      }

      println("loading " + imgUrl);
      img = loadImage(imgUrl);
      imageLoaded = true;
    }
  }

  public void onDeletionNotice(StatusDeletionNotice statusDeletionNotice) {
    //System.out.println("Got a status deletion notice id:" + statusDeletionNotice.getStatusId());
  }
  public void onTrackLimitationNotice(int numberOfLimitedStatuses) {
    //  System.out.println("Got track limitation notice:" + numberOfLimitedStatuses);
  }
  public void onScrubGeo(long userId, long upToStatusId) {
    System.out.println("Got scrub_geo event userId:" + userId + " upToStatusId:" + upToStatusId);
  }

  public void onException(Exception ex) {
    ex.printStackTrace();
  }
};

// Twitter doesn't recognize images from other sites as media, so must be parsed manually
// You can add more services at the top if something is missing

String parseTwitterImg(String pageUrl) {

  for (int i=0; i<imageService.length; i++) {
    if (pageUrl.startsWith(imageService[i][0])) {

      String fullPage = "";  // container for html
      String lines[] = loadStrings(pageUrl); // load html into an array, then move to container
      for (int j=0; j < lines.length; j++) { 
        fullPage += lines[j] + "\n";
      }

      String[] pieces = split(fullPage, imageService[i][1]);
      pieces = split(pieces[1], "\""); 

      return(pieces[0]);
    }
  }
  return(null);
}

