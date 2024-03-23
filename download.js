#!/usr/bin/env node
import puppeteer from "puppeteer"

async function waitUntilDownload(page, fileName = '') {
    return new Promise((resolve, reject) => {
        page._client().on('Page.downloadProgress', e => { // or 'Browser.downloadProgress'
            if (e.state === 'completed') {
                resolve(fileName);
            } else if (e.state === 'canceled') {
                reject();
            }
        });
    });
}

(async () => {
    console.log( "Starting browser");
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    })
    
    const page = await browser.newPage()
    
    page.target().createCDPSession().then((client) => {
        return client.send('Page.setDownloadBehavior', {
            behavior: 'allow',
            downloadPath: '/tmp'})
    });
    
    console.log( "Loading download page" );
    await page.goto(
        'https://afdc.energy.gov/fuels/electricity_locations.html#/analyze?fuel=ELEC',
        { waitUntil: 'networkidle0' }
    );
    
    const element = await page.waitForSelector('a.afdc-btn');
    
    console.log( "Starting download" )
    
    await element.click();
    await waitUntilDownload( page );
    
    console.log( "Download complete" )
    
    // Close browser.
    await browser.close();
    
})()
