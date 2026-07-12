// @ts-check
import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";

// https://astro.build/config
export default defineConfig({
  integrations: [
    starlight({
      title: "ocaat",
      description: "A careful command-line interface for operating an AT Protocol PDS.",
      favicon: "/favicon.svg",
      social: [
        { icon: "github", label: "GitHub", href: "https://github.com/desertthunder/ocaat" },
        { icon: "blueSky", label: "BlueSky", href: "https://aturi.to/profile/desertthunder.dev" },
      ],
      customCss: ["/src/styles/custom.css"],
      sidebar: [
        {
          label: "Start here",
          items: [
            { label: "Overview", slug: "guides/overview" },
            { label: "First steps", slug: "guides/getting-started" },
          ],
        },
        {
          label: "Guides",
          items: [{ autogenerate: { directory: "guides" } }],
        },
        {
          label: "CLI reference",
          items: [{ autogenerate: { directory: "reference" } }],
        },
      ],
    }),
  ],
});
