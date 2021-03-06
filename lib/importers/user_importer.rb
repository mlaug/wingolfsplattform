require 'importers/importer'
require 'importers/models/user'
require 'importers/models/string'
require 'importers/models/profile_field'
require 'importers/models/netenv_user'

class UserImporter < Importer
  
  def initialize( args = {} )
    super(args)
    @object_class_name = "User"
    if @continue_with.in? [:last_user, :auto]
      if File.exists? @continue_with_file
        @continue_with = File.open(@continue_with_file, 'r') { |file| file.read }
      else
        @continue_with = nil
      end
    end
  end
  
  def import
    log.head "Wingolfsplattform User Import"
    
    log.section "Import Parameters"
    log.info "Import file:   #{@filename}"
    log.info "Results log:   #{@results_log_file}" if @results_log_file.present?
    log.info "Import filter: #{@filter || 'none'}"
    log.info "Continue import with #{@continue_with}." if @continue_with
    
    log.section "Progress"
    log.info ". = successfully created, u = successfully updated, I = ignored, W = warning, F = failure"
    
    import_file = ImportFile.new( filename: @filename, data_class_name: "NetenvUser" )
    import_file.each_row do |netenv_user|
      
      # Wenn bei einem bestimmten Benutzer fortgesetzt werden soll, vorige Datensätze
      # ohne jeden Hinweis übergehen.
      #
      next if before_point_of_continuation?(netenv_user, @continue_with)
      
      # Benutzer, die dem Import-Filter nicht entsprechen, werden übergangen.
      # Der Import-Filter wird beim Aufruf des Imports in lib/tasks/import_users.rake
      # gesetzt.
      #
      next unless netenv_user.match? @filter
      
      # Test-Benutzer des bisherigen Betreibers werden ignoriert.
      # 
      next if dummy_user? netenv_user
      
      # Duplikat-Benutzer werden ignoriert.
      # Siehe Trello-Karte: https://trello.com/c/Fv4eMohq/510-doppelte-user
      #
      next if duplicate_or_mistaken_user? netenv_user
      
      # Benutzer, die in der Datenbank des bisherigen Betreibers als gelöscht markiert
      # sind, wurden versehentlich angelegt. Ihre Daten werden nicht importiert.
      #
      next if deleted_user? netenv_user
      
      # Den Benutzer festhalten, bei dem der Import gerade ist, sodass man dem Import
      # mit der Option 'continue_with: :last_user' fortgesetzt werden kann.
      #
      save_point_of_continuation_for netenv_user
      
      # Falls die E-Mail-Adresse bereits im neuen System vergeben ist, und zwar einem
      # anderen Benutzer, liegt hier vermutlich ein Fehler vor. Deswegen wird eine Warnung
      # angezeigt. Der vorhandene Benutzer behält seine E-Mail-Adresse. Der zweite Benutzer
      # wird zwar angelegt, aber ohne E-Mail-Adresse. 
      # Ferner werden ungültige E-Mail-Adressen nicht mit ins System importiert.
      # 
      netenv_user.do_not_import_primary_email if email_issue? netenv_user
      
      # Existierenden Benutzer des neuen Systems heraussuchen oder einen neuen Benutzer
      # anlegen, falls noch keiner existiert.
      # 
      updating_user = find_existing_user_for(netenv_user) ? true : false
      user = find_or_build_user_for netenv_user
      
      # Grundlegende Attribute übernehmen.
      # Vor- und Zuname, E-Mail-Adresse, W-Nummer, Geburtsdatum.
      # 
      user.import_basic_attributes_from netenv_user
      user.save
      
      # Profilfelder importieren.
      # 
      user.import_general_profile_fields_from netenv_user
      user.import_contact_profile_fields_from netenv_user
      user.import_study_profile_fields_from netenv_user
      user.import_professional_profile_fields_from netenv_user
      user.import_profile_fields_about_me_from netenv_user
      user.import_bank_profile_fields_from netenv_user
      user.import_communication_profile_fields_from netenv_user
      user.create_template_profile_fields_where_non_existant
      
      # Mitgliedschaften in Korporationen importieren.
      # 
      check_corporation_memberships_consistency_for netenv_user
      user.import_corporation_memberships_from netenv_user
      perform_consistency_check_for_aktivitaetszahl_for user, netenv_user
      make_sure_all_corporation_memberships_have_been_imported_for user, netenv_user
      
      # BV-Zuordnung.
      #
      user.import_bv_membership_from netenv_user
      
      # Benutzer ggf. verstecken.
      #
      user.import_hidden_status_from netenv_user
      
      # Zeitstempel des Datensatzes importieren.
      # created_at, updated_at.
      #
      user.import_timestamps_from netenv_user
      
      # Fortschritt festhalten. In Abhängigkeit davon, ob ein neuer Benutzer angelegt oder
      # ein vorhandener aktualisiert wurde, wird ein entsprechendes Symbol angezeigt.
      #
      progress.log_success(updating_user)
    end

    log.info ""
    log.section "Results"    
    progress.print_status_report
  end
  
  def before_point_of_continuation?(netenv_user, continue_with)
    if continue_with.present? and (netenv_user.w_nummer < continue_with)
      progress.log_skip
      return true
    end
  end  
  
  def dummy_user?(netenv_user)
    if netenv_user.dummy_user?
      warning = { message: "Der Test-Benutzer #{netenv_user.w_nummer} wird nicht importiert. Kein Handlungsbedarf.",
        w_nummer: netenv_user.w_nummer, name: netenv_user.name,
        netenv_aktivitätszahl: netenv_user.netenv_aktivitätszahl
      }
      progress.log_ignore(warning)
      return true
    end
  end
  
  def duplicate_or_mistaken_user?(netenv_user)
    if netenv_user.duplicate_or_mistaken_user?
      warning = { message: "Der fälschlicherweise angelegte Duplikat-Benutzer #{netenv_user.w_nummer} wird nicht importiert. Kein Handlungsbedarf.",
        w_nummer: netenv_user.w_nummer, name: netenv_user.name,
        netenv_aktivitätszahl: netenv_user.netenv_aktivitätszahl
      }
      progress.log_ignore(warning)
      return true
    end
  end
  
  def deleted_user?(netenv_user)
    if netenv_user.deleted?
      warning = { message: "Der Benutzer #{netenv_user.w_nummer} wurde als gelöscht markiert und wird nicht importiert. Kein Handlungsbedarf.",
                  w_nummer: netenv_user.w_nummer, name: netenv_user.name }
      progress.log_ignore(warning)
      return true
    end
  end
  
  def email_issue?(netenv_user)
    return false if netenv_user.email.blank?
    email_duplicate?(netenv_user) or wrong_email_format?(netenv_user)
  end
  
  def email_duplicate?(netenv_user)
    existing_user_with_this_email = User.find_by_email(netenv_user.email)
    return false unless existing_user_with_this_email

    if existing_user_with_this_email.w_nummer != netenv_user.w_nummer
      warning = { message: "Doppelt vergebene E-Mail-Adresse #{netenv_user.email}. In diesem Import wird sie dem Benutzer #{existing_user_with_this_email.w_nummer} zugeschrieben. Der Benutzer #{netenv_user.w_nummer} wird ohne E-Mail-Adresse importiert. Telefonischer Rücksprache erforderlich.",
        w_nummer: netenv_user.w_nummer, name: netenv_user.name, email: netenv_user.email,
        existing_user: existing_user_with_this_email.w_nummer, existing_user_name: existing_user_with_this_email.name 
      }
      progress.log_warning(warning)
      return true
    end
  end
  
  def wrong_email_format?(netenv_user)
    if (not netenv_user.email.include?('@')) or (not netenv_user.email.include?('.'))
      warning = { message: "Die E-Mail-Adresse '#{netenv_user.email}' des Benutzers #{netenv_user.w_nummer} ist ungültig und wird nicht importiert.",
                  w_nummer: netenv_user.w_nummer, email: netenv_user.email }
      progress.log_warning(warning)
      return true
    end
  end
  
  def find_or_build_user_for(netenv_user)
    find_existing_user_for(netenv_user) || User.new
  end
  
  def find_existing_user_for(netenv_user)
    User.find_by_w_nummer(netenv_user.w_nummer)
  end
  
  def check_corporation_memberships_consistency_for(netenv_user)
    
    # Aktivmeldungsdatum?
    if not netenv_user.aktivmeldungsdatum
      warning = { message: 'Kein Aktivmeldungsdatum angegeben.',
                  name: netenv_user.name, w_nummer: netenv_user.w_nummer }
      progress.log_failure(warning)
    end
    
    # Aktivmeldungsdatum inkonsistent?
    if ( netenv_user.aktivmeldungsdatum_in_mutterverbindung and
         netenv_user.aktivmeldungsdatum_im_wingolfsbund and
         (netenv_user.aktivmeldungsdatum_im_wingolfsbund != netenv_user.aktivmeldungsdatum_in_mutterverbindung)
         )
      warning = { message: 'Inkonsistentes Aktivmeldungsdatum: Das Beitrittsdatum in den Wingolfsbund weicht vom Aktivmeldungsdatum in der Mutterverbindung ab.',
                  name: netenv_user.name, w_nummer: netenv_user.w_nummer,
                  aktivmeldungsdatum_im_wingolfsbund: netenv_user.aktivmeldungsdatum_im_wingolfsbund,
                  aktivmeldungsdatum_in_mutterverbindung: netenv_user.aktivmeldungsdatum_in_mutterverbindung,
                  mutterverbindung: netenv_user.primary_corporation.token }
      progress.log_warning(warning)
    end

    if netenv_user.aktivmeldungsdatum_aus_aktivitaetszahl.year != netenv_user.angegebenes_aktivmeldungsdatum.try(:year)
      if netenv_user.angegebenes_aktivmeldungsdatum
        warning = { message: 'Inkonsistentes Aktivmeldungsdatum: Das Aktivmeldungsdatum widerspricht der Aktivitätszahl.',
                    name: netenv_user.name, w_nummer: netenv_user.w_nummer,
                    angegebenes_aktivmeldungsdatum: netenv_user.angegebenes_aktivmeldungsdatum,
                    netenv_aktivitätszahl: netenv_user.netenv_aktivitätszahl,
                    ehemalige_netenv_aktivitätszahl: netenv_user.ehemalige_netenv_aktivitätszahl
                  }
        progress.log_warning(warning)
      end
    end
    
    # Receptionsdatum > Philistrationsdatum?
    if netenv_user.philistrationsdatum and netenv_user.receptionsdatum
      if netenv_user.receptionsdatum > netenv_user.philistrationsdatum
        warning = { message: 'Inkonsistenz: Das Philistrationsdatum liegt vor dem Receptionsdatum.',
                    name: netenv_user.name, w_nummer: netenv_user.w_nummer, 
                    philistrationsdatum: netenv_user.philistrationsdatum,
                    receptionsdatum: netenv_user.receptionsdatum }
        progress.log_warning(warning)
      end
    end
  end
  
  def perform_consistency_check_for_aktivitaetszahl_for( user, netenv_user )
    if netenv_user.aktivitätszahl.to_s != user.reload.aktivitätszahl.to_s
      warning = { 
        message: "Konsistenzprüfung fehlgeschlagen: Die rekonstruierte Aktivitätszahl '#{user.aktivitätszahl}' entspricht nicht der angegebenen Aktivitätszahl '#{netenv_user.aktivitätszahl}' des Benutzers #{netenv_user.w_nummer}. Dieser Benutzer muss nach Korrektur erneut importiert werden. Sonst hat ein Nicht-Wingolfit evtl. zu viele Rechte!",
        name: netenv_user.name, w_nummer: netenv_user.w_nummer,
        angegebene_aktivitätszahl: netenv_user.aktivitätszahl,
        rekonstruierte_aktivitätszahl: user.aktivitätszahl
      }
      progress.log_failure(warning)
    end
  end
  
  # Sicherstellen, dass für alle Korporationen, die in Netenv für diesen Benutzer eingetragen sind,
  # auch im neuen System einge Mitgliedschaft vorliegt.
  #
  def make_sure_all_corporation_memberships_have_been_imported_for( user, netenv_user )
    for corporation in netenv_user.corporations 
      if not user.reload.in? corporation.descendant_users
        warning = {
          message: "Konsistenzprüfung fehlgeschlagen: Für den Benutzer #{user.w_nummer} ist im alten System eine Mitgliedschaft in der Korporation '#{corporation.token}' vorgesehen. Es wurde jedoch keine solche Mitgliedschaft importiert. Prüfung und Korrektur des Import-Skripts sowie erneuter Import sind erforderlich.",
          name: netenv_user.name, w_nummer: user.w_nummer,
          corporation: corporation.token
        }
        progress.log_failure(warning)
      end
    end
  end
  
  # Den Benutzer abspeichern, bei dem wir gerade sind.
  #
  def save_point_of_continuation_for( netenv_user )
    File.open(@continue_with_file, 'w') { |file| file.write netenv_user.w_nummer } if @continue_with_file
  end
  
end
