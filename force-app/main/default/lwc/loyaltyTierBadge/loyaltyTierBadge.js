import { LightningElement, api } from 'lwc';
import PROESIS_LOYALTY_BADGES from '@salesforce/resourceUrl/Proesis_Loyalty_Badges';

import getLoyaltyBadgeDisplaySettings from '@salesforce/apex/LoyaltyLevelService.getLoyaltyBadgeDisplaySettings';

export default class LoyaltyTierBadge extends LightningElement {
    @api width;
    @api height;
    @api loyaltyTierName;
    @api hideName = false;

    badgeSettings;
    currentBadgeFileName;
    isInitialized = false;

    get badgeWidth() {
        return this.width || "32px";
    }

    get badgeHeight() {
        return this.height || "32px";
    }

    get fullBadgeFilePath() {
        if (!this.currentBadgeFileName) {
            return '';
        }

        return `${PROESIS_LOYALTY_BADGES}/badges/${this.currentBadgeFileName}.svg#Layer_1`;
    }

    async renderedCallback() {
        if (!this.isInitialized) {
            try {
                this.badgeSettings = await getLoyaltyBadgeDisplaySettings();
                this.isInitialized = true;
            } catch(e) {
                console.error(e);
            }
        }

        if (this.isInitialized) {
            let badgeSettings = this.badgeSettings.find(badgeSetting => badgeSetting.badgeName === this.loyaltyTierName);
            console.log(`Trying to Fetch: ${this.loyaltyTierName}`, badgeSettings);

            if (!badgeSettings) {
                return;
            }

            let targetBadgeFileName = (this.hideName) ? badgeSettings.noNameBadgeFileName : badgeSettings.fullBadgeFileName;

            if (targetBadgeFileName && targetBadgeFileName !== this.currentBadgeFileName) {
                this.currentBadgeFileName = targetBadgeFileName;
            }
        }
    }
}