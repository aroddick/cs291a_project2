require 'sinatra'
require 'google/cloud/storage'
require 'json'
require 'digest'
require 'pp'

storage = Google::Cloud::Storage.new(project_id: 'cs291a')
bucket = storage.bucket 'cs291project2', skip_lookup: true

get '/' do
    redirect to('/files/')
end

get '/files/' do
    fileNames = bucket.files.map { |file| file.name }
    fileNames.delete_if{ |fileName| !isFileNameValid(fileName: fileName)}
    digest = fileNames.map{ |fileName| fileName.delete('/')}
    "#{digest.to_json}\n"
end

get '/files/:file' do
    if params['file'][/\H/] || params['file'].length != 64
        status 422
        return
    end
    fileName = params['file'].downcase.insert(2, '/').insert(5, '/')
    file = bucket.file fileName
    PP.pp file
    if !file&.exists?
        status 404
        return
    end
    contentType = file.content_type
    contentDisposition = file.content_disposition
    downloadedFile = file.download
    downloadedFile.rewind
    response['content-type'] = contentType
    response['content-disposition'] = contentDisposition
    "#{downloadedFile.read}"
end

post '/files/' do
    PP.pp request
    if params['file'] == nil || params['file']['tempfile'] == nil
        status 422
        return
    end
    contentType = params['file']['type']
    tempFile = params['file']['tempfile']
    if tempFile.is_a?(String)
        status 422
        return
    end
    if tempFile.size > 1024 * 1024
        status 422
        return
    end
    data = tempFile.read
    digest = Digest::SHA256.hexdigest data
    fileName = digest.dup
    fileName = fileName.insert(2, '/').insert(5, '/')
    file = bucket.file fileName
    if file != nil
        status 409
        return
    end
    bucket.create_file tempFile, fileName
    file = bucket.file fileName
    file.content_type = contentType
    status 201
    "#{{"uploaded" => digest}.to_json}\n"
end

delete '/files/:file' do
    if params['file'][/\H/] || params['file'].length != 64
        status 422
        return
    end

    fileName = params['file'].downcase.insert(2, '/').insert(5, '/')
    file = bucket.file fileName
    if file != nil
        file.delete
    end
end

def isFileNameValid(fileName:)
    if fileName.length != 66
        print("Wrong length")
        return false
    end
    if fileName[2] != '/' && fileName[5] != '/'
        print("No slashes")
        return false
    end
    fileName = fileName.delete('/')
    if fileName[/\H/] || fileName.length != 64
        print("#{fileName} Not hex")
        return false
    end
    if fileName != fileName.downcase
        return false
    end
    return true
end