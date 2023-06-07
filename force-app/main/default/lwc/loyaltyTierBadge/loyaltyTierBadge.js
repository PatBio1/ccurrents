import { LightningElement, api } from 'lwc';
import PROESIS_LOYALTY_BADGES from '@salesforce/resourceUrl/Proesis_Loyalty_Badges';

import getLoyaltyBadgeDisplaySettings from '@salesforce/apex/LoyaltyLevelService.getLoyaltyBadgeDisplaySettings';

export default class LoyaltyTierBadge extends LightningElement {
    @api width;
    @api height;
    @api loyaltyTierName;
    @api hideName = false;

    badgeSettings;
    fullBadgeFilePath;

    get badgeWidth() {
        return this.width || "32px";
    }

    get badgeHeight() {
        return this.height || "32px";
    }

    connectedCallback() {
        this.init();
    }

    async init() {
        try {
            this.badgeSettings = await getLoyaltyBadgeDisplaySettings();
        } catch(e) {
            console.error(e);
        }

        let badgeSettings = this.badgeSettings.find(badgeSetting => badgeSetting.badgeName === this.loyaltyTierName);
        if (!badgeSettings) {
            return;
        }

        this.fullBadgeFilePath = `${PROESIS_LOYALTY_BADGES}/badges/${(this.hideName) ? badgeSettings.noNameBadgeFileName : badgeSettings.fullBadgeFileName}.svg#Layer_1`;
    }
}