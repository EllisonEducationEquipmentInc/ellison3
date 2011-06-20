// This script and many more are available free online at The JavaScript Source!! http://javascript.internet.com
// Created by DendE PhisH

function getTime() {
c1 = new Image(); c1.src = "http://www.sizzix.co.uk/images/static/clock1/1c.png";
c2 = new Image(); c2.src = "http://www.sizzix.co.uk/images/static/clock1/2c.png";
c3 = new Image(); c3.src = "http://www.sizzix.co.uk/images/static/clock1/3c.png";
c4 = new Image(); c4.src = "http://www.sizzix.co.uk/images/static/clock1/4c.png";
c5 = new Image(); c5.src = "http://www.sizzix.co.uk/images/static/clock1/5c.png";
c6 = new Image(); c6.src = "http://www.sizzix.co.uk/images/static/clock1/6c.png";
c7 = new Image(); c7.src = "http://www.sizzix.co.uk/images/static/clock1/7c.png";
c8 = new Image(); c8.src = "http://www.sizzix.co.uk/images/static/clock1/8c.png";
c9 = new Image(); c9.src = "http://www.sizzix.co.uk/images/static/clock1/9c.png";
c0 = new Image(); c0.src = "http://www.sizzix.co.uk/images/static/clock1/0c.png";
Cc = new Image(); Cc.src = "http://www.sizzix.co.uk/images/static/clock1/Cc.png";
now = new Date();

// ENTER BELOW THE DATE YOU WISH TO COUNTDOWN TO
later = new Date("June 20 2011 0:00:01");

days = (later - now) / 1000 / 60 / 60 / 24;
daysRound = Math.floor(days);
hours = (later - now) / 1000 / 60 / 60 - (24 * daysRound);
hoursRound = Math.floor(hours);
minutes = (later - now) / 1000 /60 - (24 * 60 * daysRound) - (60 * hoursRound);
minutesRound = Math.floor(minutes);
seconds = (later - now) / 1000 - (24 * 60 * 60 * daysRound) - (60 * 60 * hoursRound) - (60 * minutesRound);
secondsRound = Math.round(seconds);

if (secondsRound <= 9) {
document.images.g.src = c0.src;
document.images.h.src = eval("c"+secondsRound+".src");
}
else {
document.images.g.src = eval("c"+Math.floor(secondsRound/10)+".src");
document.images.h.src = eval("c"+(secondsRound%10)+".src");
}
if (minutesRound <= 9) {
document.images.d.src = c0.src;
document.images.e.src = eval("c"+minutesRound+".src");
}
else {
document.images.d.src = eval("c"+Math.floor(minutesRound/10)+".src");
document.images.e.src = eval("c"+(minutesRound%10)+".src");
}
if (hoursRound <= 9) {
document.images.y.src = c0.src;
document.images.z.src = eval("c"+hoursRound+".src");
}
else {
document.images.y.src = eval("c"+Math.floor(hoursRound/10)+".src");
document.images.z.src = eval("c"+(hoursRound%10)+".src");
}
if (daysRound <= 9) {
document.images.x.src = c0.src;
document.images.a.src = c0.src;
document.images.b.src = eval("c"+daysRound+".src");
}
if (daysRound <= 99) {
document.images.x.src = c0.src;
document.images.a.src = eval("c"+Math.floor((daysRound/10)%10)+".src");
document.images.b.src = eval("c"+Math.floor(daysRound%10)+".src");
}
if (daysRound <= 999){
document.images.x.src = eval("c"+Math.floor(daysRound/100)+".src");
document.images.a.src = eval("c"+Math.floor((daysRound/10)%10)+".src");
document.images.b.src = eval("c"+Math.floor(daysRound%10)+".src");
}
newtime = window.setTimeout("getTime();", 1000);
}
