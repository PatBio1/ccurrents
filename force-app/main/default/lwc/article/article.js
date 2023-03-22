import { api, LightningElement } from 'lwc';
import labels from 'c/labelService';

export default class MyRewards extends LightningElement {

    labels = labels;
    bookmarked = false;

    @api backLabel;

    onBackButtonClick() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    onBookmarkClick(event) {
        this.bookmarked = !this.bookmarked;
    }

}