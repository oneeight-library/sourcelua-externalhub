/**
 * Roblox API Service
 * Handles avatar headshots, user profiles, and username lookups with in-memory caching.
 */

const avatarCache = new Map();   // userId -> imageUrl
const userCache = new Map();     // username -> { userId, displayName }

export const robloxService = {
  /**
   * Get 150x150 circular avatar headshot for a given userId
   * @param {string|number} userId 
   * @param {string} size e.g. "150x150", "420x420", "48x48"
   * @param {boolean} isCircular
   * @returns {Promise<string|null>}
   */
  async getAvatarHeadshot(userId, size = "150x150", isCircular = true) {
    if (!userId || userId === "0" || userId === 0) return null;

    const cacheKey = `${userId}_${size}_${isCircular}`;
    if (avatarCache.has(cacheKey)) {
      return avatarCache.get(cacheKey);
    }

    try {
      const url = `https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=${userId}&size=${size}&format=Png&isCircular=${isCircular}`;
      const res = await fetch(url, {
        headers: { "User-Agent": "OneEight-Hub/1.0" }
      });

      if (!res.ok) return null;

      const data = await res.json();
      if (data && data.data && data.data.length > 0) {
        const item = data.data[0];
        if (item.state === "Completed" && item.imageUrl) {
          avatarCache.set(cacheKey, item.imageUrl);
          return item.imageUrl;
        }
      }
    } catch (e) {
      console.error("[robloxService] Error fetching avatar headshot:", e);
    }
    return null;
  },

  /**
   * Resolve Roblox username to numeric userId
   * @param {string} username 
   * @returns {Promise<{ userId: number, name: string, displayName: string } | null>}
   */
  async resolveUsername(username) {
    if (!username) return null;
    const lower = username.toLowerCase();

    if (userCache.has(lower)) {
      return userCache.get(lower);
    }

    try {
      const res = await fetch("https://users.roblox.com/v1/usernames/users", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "User-Agent": "OneEight-Hub/1.0"
        },
        body: JSON.stringify({
          usernames: [username],
          excludeBannedUsers: false
        })
      });

      if (!res.ok) return null;

      const data = await res.json();
      if (data && data.data && data.data.length > 0) {
        const user = data.data[0];
        const result = {
          userId: user.id,
          name: user.name,
          displayName: user.displayName || user.name
        };
        userCache.set(lower, result);
        return result;
      }
    } catch (e) {
      console.error("[robloxService] Error resolving username:", e);
    }
    return null;
  },

  /**
   * Get user profile details
   * @param {string|number} userId 
   */
  async getUserProfile(userId) {
    if (!userId) return null;
    try {
      const res = await fetch(`https://users.roblox.com/v1/users/${userId}`, {
        headers: { "User-Agent": "OneEight-Hub/1.0" }
      });
      if (res.ok) {
        return await res.json();
      }
    } catch (e) {
      console.error("[robloxService] Error fetching user profile:", e);
    }
    return null;
  }
};
