import fs from "fs";
const srcDistHtml = "./frontend/dist/index.html";
const targetDashboardHtml = "./src/dashboard.html";

if (!fs.existsSync(srcDistHtml)) {
  console.error("Dist HTML not found!");
  process.exit(1);
}
fs.copyFileSync(srcDistHtml, targetDashboardHtml);
console.log("Successfully synced frontend/dist/index.html -> src/dashboard.html");
