// SPDX-License-Identifier: MIT
///@notice Inspired by Uniswap-v3-periphery NFTSVG.sol
pragma solidity ^0.7.6;
pragma abicoder v2;

import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/math/SignedSafeMath.sol';
import 'base64-sol/base64.sol';
import './HexStrings.sol';

library NFTSVG {
    using Strings for uint256;

    struct SVGParams {
        uint256 tokenId;
        uint256 blockNumber;
        string uToken;
        string longitude;
        string name;
        string color0;
        string color1;
    }

    function generateSVG(SVGParams memory params) internal pure returns (string memory svg) {
        return
            string(
                abi.encodePacked(
                    generateSVGDefs(params),
                    generateSVGFigures(params),
                    // generateSVGRareMark(params.tokenId, params.uToken),
                    '</svg>'
                )
            );
    }

    function generateSVGDefs(SVGParams memory params) private pure returns (string memory svg) {
        svg = string(
            abi.encodePacked(
                '<svg width="512" height="512" viewBox="0 0 512 512" fill="none" xmlns="http://www.w3.org/2000/svg">',
                '<defs>',
                '<linearGradient id="g1" x1="0%" y1="50%" >',
                generateSVGColorPartOne(params),
                generateSVGColorPartTwo(params),
                '</linearGradient></defs>'
            )
        );
    }

    function generateSVGColorPartOne(SVGParams memory params) private pure returns (string memory svg) {
        string memory values0 = string(abi.encodePacked('#', params.color0, '; #', params.color1));
        string memory values1 = string(abi.encodePacked('#', params.color1, '; #', params.color0));
        svg = string(
            abi.encodePacked(
                '<stop offset="0%" stop-color="#',
                params.color0,
                '" >',
                '<animate id="a1" attributeName="stop-color" values="',
                values0,
                '" begin="0; a2.end" dur="3s" />',
                '<animate id="a2" attributeName="stop-color" values="',
                values1,
                '" begin="a1.end" dur="3s" /></stop>'
            )
        );
    }

    function generateSVGColorPartTwo(SVGParams memory params) private pure returns (string memory svg) {
        string memory values0 = string(abi.encodePacked('#', params.color0, '; #', params.color1));
        string memory values1 = string(abi.encodePacked('#', params.color1, '; #', params.color0));
        svg = string(
            abi.encodePacked(
                '<stop offset="100%" stop-color="#',
                params.color1,
                '" >',
                '<animate id="a3" attributeName="stop-color" values="',
                values1,
                '" begin="0; a4.end" dur="3s" />',
                '<animate id="a4" attributeName="stop-color" values="',
                values0,
                '" begin="a3.end" dur="3s" /></stop>'
            )
        );
    }

    // function generateSVGText(SVGParams memory params) private pure returns (string memory svg) {
    //     svg = string(
    //         abi.encodePacked(
    //             '<g fill="white" font-family="Poppins, monospace"><text font-size="36" x="30" y="60">',
    //             params.name,
    //             '</text><text x="30" y="440">Block: #',
    //             params.blockNumber.toString(),
    //             '</text><text x="30" y="470">ID: ',
    //             params.tokenId.toString(),
    //             '</text></g>'
    //         )
    //     );
    // }

    function generateSVGFigures(SVGParams memory params) private pure returns (string memory svg) {
        svg = string(
            abi.encodePacked(
                '<rect id="r" x="0" y="0" rx="26" ry="26" width="512" height="512" fill="url(#g1)" />',
                // generateSVGText(params),
                // '<g fill="rgba(0,0,0,0.6)" style="transform: translate(33%,33%);">',
                // '<path xmlns="http://www.w3.org/2000/svg" id="Shape" d="M201.17,60a38.81,38.81,0,0,0-38.84,38.71v42.92c-4,.27-8.09.44-12.33,0.44s-8.31.17-12.33,0.41V98.71a38.84,38.84,0,0,0-77.67,0V201.29a38.84,38.84,0,0,0,77.67,0V158.37c4-.27,8.09-0.44,12.33-0.44s8.31-.17,12.33-0.41v43.77a38.84,38.84,0,0,0,77.67,0V98.71A38.81,38.81,0,0,0,201.17,60ZM98.83,75.86a22.91,22.91,0,0,1,22.92,22.85v45.45a130.64,130.64,0,0,0-33,9.33,60,60,0,0,0-12.8,7.64V98.71A22.91,22.91,0,0,1,98.83,75.86Zm22.92,125.43a22.92,22.92,0,1,1-45.84,0V191c0-9.09,7.2-17.7,19.27-23.06a113,113,0,0,1,26.57-7.77v41.12Zm79.42,22.85a22.91,22.91,0,0,1-22.92-22.85V155.84a130.64,130.64,0,0,0,33-9.33,60,60,0,0,0,12.8-7.64v62.42A22.91,22.91,0,0,1,201.17,224.14ZM204.82,132a113,113,0,0,1-26.57,7.77V98.71a22.92,22.92,0,1,1,45.84,0V109C224.09,118.05,216.89,126.66,204.82,132Z" transform="translate(-60 -60)"/></g>',
                '<rect x="16" y="16" width="480" height="480" rx="16" ry="16" fill="rgba(0,0,0,0)" stroke="rgba(255,255,255,0.4)"></rect>',
                '<rect x="0" y="0" width="512" height="512" rx="25" ry="25" fill="rgba(0,0,0,0)" stroke="rgba(255,255,255,0.4)"></rect>'
            )
        );
    }

    // function generateSVGRareMark(uint256 tokenId, string memory tokenAddress) private pure returns (string memory svg) {
    //     if (isRare(tokenId, tokenAddress)) {
    //         svg = string(
    //             abi.encodePacked('<rect x="16" y="16" width="258" height="468" rx="25" ry="25" fill="black" />')
    //         );
    //     } else {
    //         svg = '';
    //     }
    // }

    // function isRare(uint256 tokenId, string memory tokenAddress) internal pure returns (bool) {
    //     // return uint256(keccak256(abi.encodePacked(tokenId, tokenAddress))) < type(uint256).max / 10;
    //     return false;
    // }
}
