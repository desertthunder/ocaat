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
          label: "Introduction",
          items: [
            { label: "Getting started", slug: "getting-started" },
            { label: "Overview", slug: "about" },
          ],
        },
        {
          label: "AT Protocol Querying",
          items: [
            { label: "Resource Resolver", slug: "protocol/resource-resolution" },
            { label: "Records", slug: "protocol/record-and-plc" },
            { label: "CAR Inspection", slug: "protocol/repository-car" },
            { label: "Lexicons and XRPC", slug: "protocol/lexicon-and-xrpc" },
            { label: "Relay, Firehose, & Jetstream", slug: "protocol/relay-and-firehose" },
            { label: "Bluesky", slug: "protocol/bluesky-conveniences" },
          ],
        },
        {
          label: "Interfaces",
          items: [
            { label: "Agent Skills", slug: "interfaces/agent-skills" },
            { label: "MCP Server", slug: "interfaces/mcp-server" },
            { label: "HTTP Gateway", slug: "interfaces/http-gateway" },
            { label: "JSONL", slug: "interfaces/batch-jsonl" },
          ],
        },
        {
          label: "PDS Management",
          items: [
            { label: "Monitor", slug: "pds/pds-observability" },
            { label: "Administration", slug: "pds/pds-administration" },
            { label: "Accounts and Sessions", slug: "pds/account-and-session-management" },
            { label: "Account Migration", slug: "pds/account-migration" },
            { label: "Repository transfer", slug: "pds/repository-transfer" },
            { label: "Blobs", slug: "pds/blob-management" },
            { label: "Tempest Backups", slug: "pds/tempest-backup" },
          ],
        },
        {
          label: "Development",
          collapsed: true,
          items: [
            { label: "Local development", slug: "development/local-development" },
            { label: "CLI conventions", slug: "development/cli-foundations" },
            { label: "Lexicon development", slug: "development/lexicon-development" },
            { label: "Generated API documentation", slug: "development/generated-api-documentation" },
          ],
        },
        {
          label: "Learn",
          collapsed: true,
          items: [
            { label: "CAR", slug: "learn/car" },
            { label: "goat", slug: "learn/goat" },
            { label: "Jetstream", slug: "learn/jetstream" },
            { label: "Repository event stream", slug: "learn/repository-event-stream" },
          ],
        },
        {
          label: "Manual",
          items: [{ autogenerate: { directory: "reference" } }],
        },
      ],
    }),
  ],
});
