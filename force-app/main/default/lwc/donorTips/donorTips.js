import { LightningElement } from 'lwc';
import labels from 'c/labelService';

import DonorTipVideoModal from 'c/donorTipVideoModal';

const AVAILABLE_TIP_LINKS = {
    sections: [
        {
            title: labels.learnMoreSectionTitle,
            links: [
                {
                    linkText: labels.donorTipDonorIdReqsText,
                    youtubeVideoUrl: labels.donorTipDonorIdReqsVideoId // English vs Spanish links are different, will be handled via translations
                },
                {
                    linkText: labels.donorTipApptRulesText,
                    youtubeVideoUrl: labels.donorTipApptRulesVideoId
                },
                {
                    linkText: labels.donorTipDonationProcessText,
                    youtubeVideoUrl: labels.donorTipDonationProcessVideoId
                },
                {
                    linkText: labels.donorTipHealthHistoryText,
                    youtubeVideoUrl: labels.donorTipHealthHistoryVideoId
                }
            ]
        },
        {
            title: labels.newDonorSectionTitle,
            links: [
                {
                    linkText: labels.donorTipFirstAppointmentText,
                    youtubeVideoUrl: labels.donorTipFirstAppointmentVideoId
                },
                {
                    linkText: labels.donorTipLoyaltyProgramText,
                    youtubeVideoUrl: labels.donorTipLoyaltyProgramVideoId
                },
                {
                    linkText: labels.donorTipHealthHistoryOnlineText,
                    youtubeVideoUrl: labels.donorTipHealthHistoryOnlineVideoId
                },
                {
                    linkText: labels.donorTipRedeemingPointsText,
                    youtubeVideoUrl: labels.donorTipRedeemingPointsVideoId
                },
                {
                    linkText: labels.donorTipDonationDayText,
                    youtubeVideoUrl: labels.donorTipDonationDayVideoId
                }
            ]
        }
    ]
}

export default class DonorTips extends LightningElement {

    labels = labels;
    tipLinks = AVAILABLE_TIP_LINKS;


    handleSelectDonorTip(event) {
        let targetYoutubeUrl = event.currentTarget.dataset.tipVideoUrl;

        DonorTipVideoModal.open({
            linkText: event.currentTarget.innerText,
            youtubeVideoUrl: targetYoutubeUrl
        });
    }
}