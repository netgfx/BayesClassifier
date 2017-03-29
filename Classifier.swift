//
//  Classifier.swift

import Foundation
import SwiftyJSON

class Classifier {

	var tokenizer: String = ""
	var vocabulary: Dictionary<String, Bool> = [:]
	var vocabularySize: Int = 0
	var totalDocuments: Int = 0
	var docCount: Dictionary<String, Int> = [:]
	var wordCount: Dictionary<String, Int> = [:]
	var wordFrequencyCount: Dictionary<String, Dictionary<String, Int>> = [:]
	var categories: Dictionary<String, Bool> = [:]
  var machineSuggestions<String, Array<String>>
	let STATE_KEYS = ["categories", "docCount", "totalDocuments", "vocabulary", "vocabularySize", "wordCount", "wordFrequencyCount", "options"
	]

	internal init() {}

	func loadFromCache(_ theList: String) -> Void {
		let list = theList
		let data = list.base64Decoded().data(using: String.Encoding.utf8)!
		let values = JSON(data: data)
		self.categories = values["categories"].dictionaryObject as! Dictionary<String, Bool>
		self.docCount = values["docCount"].dictionaryObject as! Dictionary<String, Int>
		self.totalDocuments = values["totalDocuments"].intValue
		self.vocabulary = values["vocabulary"].dictionaryObject as! Dictionary<String, Bool>
		self.vocabularySize = values["vocabularySize"].intValue
		self.wordCount = values["wordCount"].dictionaryObject as! Dictionary<String, Int>
		self.wordFrequencyCount = values["wordFrequencyCount"].dictionaryObject as! Dictionary<String, Dictionary<String, Int>>
		if values["machineSuggestions"] != nil {
			self.machineSuggestions = values["machineSuggestions"].dictionaryObject as! Dictionary<String, Array<String>>
		}
	}

	func defaultTokenizer(_ text: String) -> Array<String> {
		let okayChars: Set<Character> =
			Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890+-*=(),.:!_".characters)
		let str = String(text.characters.filter { okayChars.contains($0) })

		let charset = CharacterSet.whitespaces
		let splitted = str.characters.split(whereSeparator: { [",", "[", "]", "\n", "\r", ".", "!", ":", "?", ":", "@", "#"].contains($0) })
		let trimmed = splitted.map { String($0).trimmingCharacters(in: charset) }

		return trimmed
	}

	func Naivebayes(_ options: Dictionary<String, String>) {

		if options.count == 0 {
			print("error no options")
		}
	}

	func initializeCategory(_ categoryName: String) {
		if self.categories[categoryName] == nil {
			self.docCount[categoryName] = 0
			self.wordCount[categoryName] = 0
			self.wordFrequencyCount[categoryName] = [:]
			categories[categoryName] = true
		}
	}

	func learn(_ text: String, category: String) {
		self.initializeCategory(category)
		self.docCount[category] = self.docCount[category]! + 1
		self.totalDocuments += 1
		let tokens = self.defaultTokenizer(text)
		let frequencyTable = self.frequencyTable(tokens)

		for (item, _) in frequencyTable {
			if self.vocabulary[item] == nil {
				self.vocabulary[item] = true
				self.vocabularySize = self.vocabularySize + 1
			}

			let frequencyInText: Int = frequencyTable[item]!
			if self.wordFrequencyCount[category]![item] == nil {
				self.wordFrequencyCount[category]![item] = frequencyInText
			}
			else {
				self.wordFrequencyCount[category]![item] = self.wordFrequencyCount[category]![item]! + frequencyInText
			}

			self.wordCount[category] = self.wordCount[category]! + frequencyInText
		}

		self.machineSuggestions[category] = tokens
	}

	/**
	 teach the machine a series of names and criteria, and categorize them by alphabetical hash of the names (strings)
	 - parameter text, the stringified names and criteria
	 - parameter category, the alphabetically sorted hash (md5) to categorize the text with
	 - return Void, nothing
	 */
	func learnHash(_ text: String, category: Array<String>) -> Void {
		var hash = ""
		hash = Utils.sortAndHash(category)
		self.learn(text, category: hash)
	}

	func categorize(_ text: String) -> String {
		var maxProbability = -Float.infinity
		var chosenCategory = ""

		let tokens = self.defaultTokenizer(text)
		var _frequencyTable = self.frequencyTable(tokens)

		for (item, _) in self.categories {
			let firstPart: Float = Float(self.docCount[item]!)
			let secondPart: Float = Float(self.totalDocuments)
			let categoryProbability: Float = Float(firstPart / secondPart)

			var logProbability = log(categoryProbability)

			for (token, _) in _frequencyTable {
				let frequencyInText: Float = Float(_frequencyTable[token]!)
				let tokenProbability: Float = self.tokenProbability(token, category: item)
				print(item, token, frequencyInText, tokenProbability)
				logProbability = logProbability + (frequencyInText * log(tokenProbability))
			}

			print("FINAL LOG PROBABILITY: ", logProbability)
			if logProbability > maxProbability {
				maxProbability = logProbability
				chosenCategory = item
			}
		}

		return chosenCategory
	}

	func tokenProbability(_ token: String, category: String) -> Float {
		var wordFrequencyCount: Int!
		if let test = self.wordFrequencyCount[category]![token] {
			print(test)
		}
		if self.wordFrequencyCount[category]![token] != nil {
			wordFrequencyCount = self.wordFrequencyCount[category]![token]!
		}
		else {
			wordFrequencyCount = 0
		}

		let wordCount = self.wordCount[category]
		let firstPart: Float = Float(wordFrequencyCount + 1)
		let secondPart: Float = Float(wordCount! + self.vocabularySize)
		let test2: Float = Float(firstPart / secondPart)

        if (wordCount! + self.vocabularySize) != 0 {
            print(wordFrequencyCount!, wordCount!, self.vocabularySize, (wordFrequencyCount! + 1) / (wordCount! + self.vocabularySize))
        }
		return test2
	}

	func frequencyTable(_ tokens: Array<String>) -> Dictionary<String, Int> {

		var frequencyTable: Dictionary<String, Int> = [:]

		for key in tokens {
			if frequencyTable[key] == nil {
				frequencyTable[key] = 1
			}
			else {
				frequencyTable[key] = frequencyTable[key]! + 1
			}
		}

		return frequencyTable
	}
    
    func excludeKeysFromResults(_ key:String, arr:Array<String>) -> Array<String> {
        var results:Array<String> = arr
        let keysArr = key.components(separatedBy: ",")
        for item in keysArr {
            let index = results.index(of: item)
            if  index != nil {
                results.remove(at: index!)
            }
        }
        
        return results
    }

	func saveTokens() -> String {
		let _json: JSON = JSON([
			"categories": self.categories,
			"docCount": self.docCount,
			"totalDocuments": self.totalDocuments,
			"vocabulary": self.vocabulary,
			"vocabularySize": self.vocabularySize,
			"wordCount": self.wordCount,
			"wordFrequencyCount": self.wordFrequencyCount,
			"machineSuggestions": DataStorage.machineSuggestions
		])

		return (_json.rawString(String.Encoding(rawValue: String.Encoding.utf8.rawValue), options: JSONSerialization.WritingOptions(rawValue: 0))?.base64Encoded())!
	}
  
  /**
    Return the results
  */
  public func getMachineSuggestions() -> Dictionary<String, Array<String>> {
     return self.machineSuggestions
  }

}
