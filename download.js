#!/usr/bin/env node
import puppeteer from "puppeteer";

async function waitUntilDownload(page, fileName = "") {
  return new Promise((resolve, reject) => {
    page._client().on("Page.downloadProgress", (e) => {
      // console.log("Download progress:", e);
      if (e.state === "completed") {
        resolve(fileName);
      } else if (e.state === "canceled") {
        reject(new Error("Download was canceled"));
      }
    });

    // Add a timeout to reject the promise if download doesn't start
    setTimeout(() => {
      reject(new Error("Download timeout"));
    }, 30000); // 30 seconds timeout
  });
}

(async () => {
  try {
    console.log("Starting browser");
    const browser = await puppeteer.launch({
      headless: true,
      args: ["--no-sandbox", "--disable-setuid-sandbox"],
    });

    const page = await browser.newPage();

    page
      .target()
      .createCDPSession()
      .then((client) => {
        return client.send("Page.setDownloadBehavior", {
          behavior: "allow",
          downloadPath: "/tmp",
        });
      });

    console.log("Loading download page");
    await page.goto(
      "https://afdc.energy.gov/fuels/electricity_locations.html#/analyze?fuel=ELEC",
      { waitUntil: "networkidle0" }
    );

    const shadow = await page.waitForSelector("#afdc-stations");
    console.log("Shadow found", shadow);
    const element = await shadow.waitForSelector(">>> .analyze-download a");

    console.log("Starting download");

    await element.click();
    console.log("Waiting for download to complete...");
    await waitUntilDownload(page);

    console.log("Download complete");

    // Close browser.
    await browser.close();
  } catch (error) {
    console.error("An error occurred:", error);
    await browser.close();
  }
})();
