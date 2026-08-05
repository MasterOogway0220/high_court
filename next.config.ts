import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // The dev badge sits bottom-left, on top of the mobile tab bar's Home item —
  // which makes /demo.html unusable for showing the app. Compile and runtime
  // errors still surface without it.
  devIndicators: false,

  /*
    Opening the site shows the app inside a phone frame, not the bare dashboard.

    The frame and the app both live at "/", so the two requests are told apart by
    Sec-Fetch-Dest, which the browser sets from the request's target:

      document  a person navigating to the site   -> the phone frame
      iframe    the frame loading the app inside  -> the app
      empty     the App Router's own RSC fetches  -> the app

    That is what stops the frame loading itself forever. Tapping Home inside the
    frame is a navigation targeting the iframe, so it stays `iframe` and lands on
    the dashboard. A browser too old to send the header simply gets the app, which
    is the safe way to be wrong.
  */
  async rewrites() {
    return {
      beforeFiles: [
        {
          source: '/',
          destination: '/demo.html',
          has: [{ type: 'header', key: 'sec-fetch-dest', value: 'document' }],
        },
      ],
      afterFiles: [],
      fallback: [],
    };
  },
};

export default nextConfig;
