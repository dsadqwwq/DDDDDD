/**
 * NFT Metadata API Endpoint for Scatter
 * Returns ERC-721 compliant metadata for each token
 *
 * Pre-reveal: All tokens return the same metadata with pre-reveal image
 * Post-reveal: Update this endpoint to return unique metadata per tokenId
 */

export default function handler(req, res) {
  const { tokenId } = req.query;

  // Validate tokenId
  if (!tokenId || isNaN(tokenId)) {
    return res.status(400).json({
      error: 'Invalid token ID'
    });
  }

  // Parse tokenId as integer
  const id = parseInt(tokenId);

  // PRE-REVEAL METADATA
  // All tokens return the same metadata until reveal
  const metadata = {
    name: `Founder's Sword #${id}`,
    description: "A legendary sword forged for the earliest supporters of Duel PVP. This mystical weapon awaits its reveal to unveil its true power and unique characteristics.",
    image: "https://duelpvp.com/assets/Capture.JPG",
    attributes: [
      {
        trait_type: "Status",
        value: "Unrevealed"
      },
      {
        trait_type: "Collection",
        value: "Founder's Swords"
      },
      {
        trait_type: "Rarity",
        value: "TBA"
      }
    ]
  };

  // POST-REVEAL: Replace above with logic to fetch unique metadata per tokenId
  // Example:
  // const metadata = await fetchMetadataFromDatabase(id);
  // or
  // const metadata = metadataMap[id]; // from a JSON file

  // Set cache headers for NFT platforms
  res.setHeader('Cache-Control', 'public, max-age=3600'); // Cache for 1 hour
  res.setHeader('Content-Type', 'application/json');

  return res.status(200).json(metadata);
}
