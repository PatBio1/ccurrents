import { LightningElement, api } from 'lwc';
import LightningModal from 'lightning/modal';

export default class DonorTipVideoModal extends LightningModal {
    @api linkText;
    @api youtubeVideoId;

    get youtubeEmbedUrl() {
        return `https://www.youtube.com/embed/${this.youtubeVideoId}?rel=0`;
    }
}